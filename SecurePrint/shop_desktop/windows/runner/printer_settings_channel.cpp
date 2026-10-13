#include "printer_settings_channel.h"

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <windows.h>
#include <winspool.h>

#include <memory>
#include <string>
#include <vector>

namespace {

// Helper to convert UTF-8 string to std::wstring
std::wstring Utf8ToWide(const std::string& str) {
  if (str.empty()) {
    return L"";
  }
  int size = MultiByteToWideChar(CP_UTF8, 0, str.c_str(), -1, nullptr, 0);
  if (size <= 0) {
    return L"";
  }
  std::wstring wstr(size, 0);
  MultiByteToWideChar(CP_UTF8, 0, str.c_str(), -1, &wstr[0], size);
  if (!wstr.empty() && wstr.back() == L'\0') {
    wstr.pop_back();
  }
  return wstr;
}

}  // namespace

void RegisterPrinterSettingsChannel(flutter::BinaryMessenger* messenger) {
  auto channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      messenger, "secureprint/printer_settings",
      &flutter::StandardMethodCodec::GetInstance());

  channel->SetMethodCallHandler(
      [](const flutter::MethodCall<flutter::EncodableValue>& call,
         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
        if (!args) {
          result->Error("INVALID_ARGUMENTS", "Arguments must be a map.");
          return;
        }

        auto printer_it = args->find(flutter::EncodableValue("printerName"));
        if (printer_it == args->end() ||
            !std::holds_alternative<std::string>(printer_it->second)) {
          result->Error("INVALID_ARGUMENTS", "printerName is required.");
          return;
        }

        std::string printer_name = std::get<std::string>(printer_it->second);
        std::wstring w_printer_name = Utf8ToWide(printer_name);

        if (call.method_name() == "getPrinterCapabilities") {
          int duplex = DeviceCapabilitiesW(w_printer_name.c_str(), nullptr,
                                           DC_DUPLEX, nullptr, nullptr);
          int color = DeviceCapabilitiesW(w_printer_name.c_str(), nullptr,
                                          DC_COLORDEVICE, nullptr, nullptr);

          flutter::EncodableMap res;
          res[flutter::EncodableValue("supportsDuplex")] =
              flutter::EncodableValue(duplex == 1);
          res[flutter::EncodableValue("supportsColor")] =
              flutter::EncodableValue(color == 1);
          result->Success(flutter::EncodableValue(res));
          return;
        }

        if (call.method_name() == "applyPrinterSettings") {
          auto duplex_it = args->find(flutter::EncodableValue("duplex"));
          auto color_it = args->find(flutter::EncodableValue("colorMode"));

          std::string duplex_str =
              (duplex_it != args->end() &&
               std::holds_alternative<std::string>(duplex_it->second))
                  ? std::get<std::string>(duplex_it->second)
                  : "simplex";
          std::string color_str =
              (color_it != args->end() &&
               std::holds_alternative<std::string>(color_it->second))
                  ? std::get<std::string>(color_it->second)
                  : "color";

          bool is_duplex = (duplex_str == "duplex");
          bool is_color = (color_str == "color");

          // 1. Verify physical/driver capabilities
          int duplex_cap = DeviceCapabilitiesW(
              w_printer_name.c_str(), nullptr, DC_DUPLEX, nullptr, nullptr);
          int color_cap = DeviceCapabilitiesW(
              w_printer_name.c_str(), nullptr, DC_COLORDEVICE, nullptr, nullptr);

          if (is_duplex && duplex_cap != 1) {
            result->Error(
                "UNSUPPORTED_DUPLEX",
                "The selected printer '" + printer_name +
                    "' does not support duplex (two-sided) printing.");
            return;
          }

          if (is_color && color_cap != 1) {
            result->Error(
                "UNSUPPORTED_COLOR",
                "The selected printer '" + printer_name +
                    "' is a monochrome printer and does not support color printing.");
            return;
          }

          // 2. Open printer to inspect and apply DEVMODE settings
          HANDLE hPrinter = nullptr;
          if (!OpenPrinterW(const_cast<LPWSTR>(w_printer_name.c_str()),
                            &hPrinter, nullptr)) {
            result->Error(
                "PRINTER_OPEN_FAILED",
                "Unable to open printer '" + printer_name +
                    "' to configure print settings.");
            return;
          }

          LONG dm_size = DocumentPropertiesW(
              nullptr, hPrinter, const_cast<LPWSTR>(w_printer_name.c_str()),
              nullptr, nullptr, 0);
          if (dm_size <= 0) {
            ClosePrinter(hPrinter);
            result->Error("DEVMODE_ERROR",
                          "Unable to get DEVMODE size for printer '" +
                              printer_name + "'.");
            return;
          }

          std::vector<BYTE> in_buffer(dm_size);
          std::vector<BYTE> out_buffer(dm_size);

          auto in_dm = reinterpret_cast<DEVMODEW*>(in_buffer.data());
          auto out_dm = reinterpret_cast<DEVMODEW*>(out_buffer.data());

          // Retrieve current DEVMODE
          DocumentPropertiesW(
              nullptr, hPrinter, const_cast<LPWSTR>(w_printer_name.c_str()),
              in_dm, nullptr, DM_OUT_BUFFER);

          // Configure requested duplex and color settings
          in_dm->dmFields |= DM_DUPLEX | DM_COLOR;
          in_dm->dmDuplex = is_duplex ? DMDUP_VERTICAL : DMDUP_SIMPLEX;
          in_dm->dmColor = is_color ? DMCOLOR_COLOR : DMCOLOR_MONOCHROME;

          // Merge and validate with driver
          LONG merge_res = DocumentPropertiesW(
              nullptr, hPrinter, const_cast<LPWSTR>(w_printer_name.c_str()),
              out_dm, in_dm, DM_IN_BUFFER | DM_OUT_BUFFER);

          if (merge_res < 0) {
            ClosePrinter(hPrinter);
            result->Error(
                "MERGE_FAILED",
                "Printer driver rejected settings merge for '" +
                    printer_name + "'.");
            return;
          }

          // Strict validation: if duplex was requested, verify driver retained DM_DUPLEX
          if (is_duplex &&
              (((out_dm->dmFields & DM_DUPLEX) == 0) ||
               out_dm->dmDuplex != DMDUP_VERTICAL)) {
            ClosePrinter(hPrinter);
            result->Error(
                "UNSUPPORTED_DUPLEX",
                "Printer driver for '" + printer_name +
                    "' rejected the requested duplex mode.");
            return;
          }

          // Apply per-user DEVMODE (Level 9) so print spooling utilizes active settings
          PRINTER_INFO_9W info9;
          info9.pDevMode = out_dm;
          SetPrinterW(hPrinter, 9, reinterpret_cast<LPBYTE>(&info9), 0);
          ClosePrinter(hPrinter);

          flutter::EncodableMap res;
          res[flutter::EncodableValue("applied")] =
              flutter::EncodableValue(true);
          res[flutter::EncodableValue("duplexApplied")] =
              flutter::EncodableValue(is_duplex);
          res[flutter::EncodableValue("colorApplied")] =
              flutter::EncodableValue(is_color);
          result->Success(flutter::EncodableValue(res));
          return;
        }

        result->NotImplemented();
      });
}
