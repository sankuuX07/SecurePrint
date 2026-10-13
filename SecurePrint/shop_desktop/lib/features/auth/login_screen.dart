import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../../core/config/app_config.dart';
import '../../providers/auth_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/secure_storage.dart';
import 'sign_up_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _secureStorage = SecureStorage();

  bool _obscurePassword = true;
  bool _rememberEmail = false;
  bool _rememberSession = false;

  String? _emailError;
  String? _passwordError;

  bool _isTestingConnection = false;
  String? _connectionTestResult;
  bool? _connectionTestSuccess;

  @override
  void initState() {
    super.initState();
    // Clear any previous error on entering login screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthProvider>().clearError();
    });
    _loadRememberedEmail();
  }

  Future<void> _loadRememberedEmail() async {
    final savedEmail = await _secureStorage.getRememberedEmail();
    if (savedEmail != null && savedEmail.isNotEmpty && mounted) {
      setState(() {
        _emailController.text = savedEmail;
        _rememberEmail = true;
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool _validateInputs() {
    bool isValid = true;
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    setState(() {
      _emailError = null;
      _passwordError = null;

      if (email.isEmpty) {
        _emailError = 'Please enter your email.';
        isValid = false;
      } else {
        final emailRegex = RegExp(r'^[\w\.\-]+@([\w\-]+\.)+[\w\-]{2,4}$');
        if (!emailRegex.hasMatch(email)) {
          _emailError = 'Please enter a valid email address.';
          isValid = false;
        }
      }

      if (password.isEmpty) {
        _passwordError = 'Please enter your password.';
        isValid = false;
      }
    });

    return isValid;
  }

  void _handleLogin() {
    if (!_validateInputs()) {
      return;
    }

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    context.read<AuthProvider>().login(
          email,
          password,
          rememberSession: _rememberSession,
          rememberEmail: _rememberEmail,
        );
  }

  Future<void> _handleTestConnection([SettingsProvider? settingsProvider]) async {
    setState(() {
      _isTestingConnection = true;
      _connectionTestResult = null;
      _connectionTestSuccess = null;
    });

    final targetUrl = AppConfig.backendUrl.trim();
    if (targetUrl.isEmpty) {
      if (mounted) {
        setState(() {
          _isTestingConnection = false;
          _connectionTestSuccess = false;
          _connectionTestResult = 'No backend URL configured. Please configure in settings.';
        });
      }
      return;
    }

    bool isOnline = false;
    try {
      if (settingsProvider != null) {
        isOnline = await settingsProvider.checkBackendConnection();
      } else {
        final uri = Uri.parse('$targetUrl/');
        final response = await http.get(uri).timeout(const Duration(seconds: 4));
        isOnline = response.statusCode >= 200 && response.statusCode < 400;
      }
    } catch (_) {
      isOnline = false;
    }

    if (!mounted) return;
    setState(() {
      _isTestingConnection = false;
      _connectionTestSuccess = isOnline;
      _connectionTestResult = isOnline
          ? 'Connected to FastAPI backend ($targetUrl)'
          : 'Cannot reach backend at $targetUrl';
    });
  }

  void _showConnectionDialog(BuildContext context, SettingsProvider? settingsProvider) {
    showDialog(
      context: context,
      builder: (dialogCtx) {
        final urlController = TextEditingController(text: AppConfig.backendUrl);
        bool isTesting = false;
        String? testStatus;
        bool? testSuccess;

        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.settings, color: Colors.blue),
                  SizedBox(width: 8),
                  Text('Server & Auth Settings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              content: SizedBox(
                width: 480,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Authentication Mode', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 6),
                      RadioListTile<AuthenticationMode>(
                        value: AuthenticationMode.productionBackend,
                        groupValue: AppConfig.authMode,
                        title: const Text('Production Backend (FastAPI)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                        subtitle: const Text('Connects to FastAPI server for real authentication and jobs.', style: TextStyle(fontSize: 12)),
                        contentPadding: EdgeInsets.zero,
                        onChanged: (mode) async {
                          if (mode != null) {
                            if (settingsProvider != null) {
                              await settingsProvider.setAuthMode(mode);
                            } else {
                              AppConfig.authMode = mode;
                            }
                            setDialogState(() {});
                            if (mounted) setState(() {});
                          }
                        },
                      ),
                      RadioListTile<AuthenticationMode>(
                        value: AuthenticationMode.localDevelopment,
                        groupValue: AppConfig.authMode,
                        title: const Text('Local Development (Offline Demo)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                        subtitle: const Text('Isolated offline testing using local dummy accounts.', style: TextStyle(fontSize: 12)),
                        contentPadding: EdgeInsets.zero,
                        onChanged: (mode) async {
                          if (mode != null) {
                            if (settingsProvider != null) {
                              await settingsProvider.setAuthMode(mode);
                            } else {
                              AppConfig.authMode = mode;
                            }
                            setDialogState(() {});
                            if (mounted) setState(() {});
                          }
                        },
                      ),
                      const Divider(height: 24),
                      const Text('Environment', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 6),
                      DropdownButton<Environment>(
                        isExpanded: true,
                        value: AppConfig.currentEnvironment,
                        items: Environment.values.map((env) {
                          String label = env.name.toUpperCase();
                          if (env == Environment.development) label += ' (http://127.0.0.1:8000)';
                          if (env == Environment.lanTesting) label += ' (http://192.168.1.100:8000)';
                          return DropdownMenuItem(value: env, child: Text(label, style: const TextStyle(fontSize: 13)));
                        }).toList(),
                        onChanged: (env) async {
                          if (env != null) {
                            if (settingsProvider != null) {
                              await settingsProvider.setEnvironment(env);
                            } else {
                              AppConfig.currentEnvironment = env;
                            }
                            urlController.text = AppConfig.backendUrl;
                            setDialogState(() {});
                            if (mounted) setState(() {});
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      const Text('Backend URL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: urlController,
                              decoration: const InputDecoration(
                                hintText: 'e.g. http://127.0.0.1:8000',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              ),
                              style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () async {
                              if (settingsProvider != null) {
                                await settingsProvider.setBackendUrl(urlController.text);
                              } else {
                                AppConfig.customBackendUrl = urlController.text.trim();
                              }
                              setDialogState(() {
                                testStatus = 'Backend URL saved successfully.';
                                testSuccess = true;
                              });
                              if (mounted) setState(() {});
                            },
                            child: const Text('Save'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (testStatus != null)
                        Container(
                          padding: const EdgeInsets.all(8),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: testSuccess == true ? Colors.green.shade50 : Colors.red.shade50,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: testSuccess == true ? Colors.green.shade300 : Colors.red.shade300,
                            ),
                          ),
                          child: Text(
                            testStatus!,
                            style: TextStyle(
                              fontSize: 12,
                              color: testSuccess == true ? Colors.green.shade900 : Colors.red.shade900,
                            ),
                          ),
                        ),
                      Row(
                        children: [
                          OutlinedButton.icon(
                            icon: isTesting
                                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.wifi, size: 16),
                            label: const Text('Test Connection', style: TextStyle(fontSize: 12)),
                            onPressed: isTesting
                                ? null
                                : () async {
                                    setDialogState(() => isTesting = true);
                                    bool online = false;
                                    if (settingsProvider != null) {
                                      online = await settingsProvider.checkBackendConnection();
                                    } else {
                                      try {
                                        final uri = Uri.parse('${AppConfig.backendUrl}/');
                                        final res = await http.get(uri).timeout(const Duration(seconds: 4));
                                        online = res.statusCode >= 200 && res.statusCode < 400;
                                      } catch (_) {
                                        online = false;
                                      }
                                    }
                                    setDialogState(() {
                                      isTesting = false;
                                      testSuccess = online;
                                      testStatus = online
                                          ? 'Successfully connected to backend at ${AppConfig.backendUrl}'
                                          : 'Connection failed: Cannot reach backend at ${AppConfig.backendUrl}';
                                    });
                                  },
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () async {
                              if (settingsProvider != null) {
                                await settingsProvider.resetToDefaults();
                              } else {
                                AppConfig.currentEnvironment = Environment.development;
                                AppConfig.authMode = AuthenticationMode.productionBackend;
                                AppConfig.customBackendUrl = null;
                              }
                              urlController.text = AppConfig.backendUrl;
                              setDialogState(() {
                                testStatus = null;
                                testSuccess = null;
                              });
                              if (mounted) setState(() {});
                            },
                            child: const Text('Reset Defaults', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    urlController.dispose();
                    Navigator.of(dialogCtx).pop();
                  },
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildConnectionCard(SettingsProvider? settingsProvider, bool isLocalMode) {
    if (isLocalMode) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.amber.shade50,
          border: Border.all(color: Colors.amber.shade400),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.developer_mode, color: Colors.amber.shade900, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Local Development Mode (Offline)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber.shade900,
                    ),
                  ),
                ),
                IconButton(
                  key: const Key('configure_connection_button'),
                  icon: const Icon(Icons.settings, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Configure Connection',
                  onPressed: () => _showConnectionDialog(context, settingsProvider),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Offline Dev Demo - FastAPI connection disabled',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.amber.shade800,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton(
                  key: const Key('switch_to_backend_button'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: () {
                    if (settingsProvider != null) {
                      settingsProvider.setAuthMode(AuthenticationMode.productionBackend);
                    } else {
                      AppConfig.authMode = AuthenticationMode.productionBackend;
                    }
                    setState(() {
                      _connectionTestResult = null;
                      _connectionTestSuccess = null;
                    });
                  },
                  child: const Text('Switch to Backend', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        border: Border.all(color: Colors.blue.shade300),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _connectionTestSuccess == true
                    ? Icons.cloud_done
                    : (_connectionTestSuccess == false ? Icons.cloud_off : Icons.cloud_outlined),
                color: _connectionTestSuccess == true
                    ? Colors.green.shade700
                    : (_connectionTestSuccess == false ? Colors.red.shade700 : Colors.blue.shade900),
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Wrap(
                  spacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'Production Backend Mode (FastAPI)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade900,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        AppConfig.environmentName,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                key: const Key('configure_connection_button'),
                icon: const Icon(Icons.settings, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Configure Connection',
                onPressed: () => _showConnectionDialog(context, settingsProvider),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  AppConfig.backendUrl.isNotEmpty ? AppConfig.backendUrl : 'No backend URL configured',
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    color: Colors.blue.shade700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton.icon(
                key: const Key('test_connection_button'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  visualDensity: VisualDensity.compact,
                ),
                icon: _isTestingConnection
                    ? const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.wifi, size: 14),
                label: Text(_isTestingConnection ? 'Testing' : 'Test', style: const TextStyle(fontSize: 12)),
                onPressed: _isTestingConnection ? null : () => _handleTestConnection(settingsProvider),
              ),
            ],
          ),
          if (_connectionTestResult != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _connectionTestSuccess == true ? Colors.green.shade100 : Colors.red.shade100,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  Icon(
                    _connectionTestSuccess == true ? Icons.check_circle : Icons.error_outline,
                    size: 14,
                    color: _connectionTestSuccess == true ? Colors.green.shade800 : Colors.red.shade800,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _connectionTestResult!,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: _connectionTestSuccess == true ? Colors.green.shade900 : Colors.red.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _navigateToSignUp() async {
    context.read<AuthProvider>().clearError();
    final registeredEmail = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const SignUpScreen()),
    );

    if (registeredEmail != null && registeredEmail.isNotEmpty && mounted) {
      setState(() {
        _emailController.text = registeredEmail;
        _passwordController.clear();
        _emailError = null;
        _passwordError = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final settingsProvider = Provider.of<SettingsProvider?>(context);
    final isLoading = authProvider.state == AuthState.loggingIn;
    final errorMessage = authProvider.errorMessage;
    final isLocalMode = AppConfig.authMode == AuthenticationMode.localDevelopment;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Server & Connection Settings',
            onPressed: () => _showConnectionDialog(context, settingsProvider),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Logo/Branding Icon
                const Icon(
                  Icons.print_rounded,
                  size: 64,
                  color: Colors.blue,
                ),
                const SizedBox(height: 16),

                // Heading
                const Text(
                  'Welcome Back',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),

                // Subtitle
                const Text(
                  'Sign in to your shop account',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 14),

                // Interactive Connection & Auth Mode Section
                _buildConnectionCard(settingsProvider, isLocalMode),
                const SizedBox(height: 20),

                // General Error Banner (shown only when an actual error occurred)
                if (errorMessage != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            errorMessage,
                            style: TextStyle(color: Colors.red.shade800),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Email Input
                TextField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.email_outlined),
                    errorText: _emailError,
                  ),
                  keyboardType: TextInputType.emailAddress,
                  enabled: !isLoading,
                  onChanged: (_) {
                    if (_emailError != null) setState(() => _emailError = null);
                  },
                  onSubmitted: (_) => _handleLogin(),
                ),
                const SizedBox(height: 16),

                // Password Input
                TextField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.lock_outline),
                    errorText: _passwordError,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                  ),
                  obscureText: _obscurePassword,
                  enabled: !isLoading,
                  onChanged: (_) {
                    if (_passwordError != null) setState(() => _passwordError = null);
                  },
                  onSubmitted: (_) => _handleLogin(),
                ),
                const SizedBox(height: 12),

                // Remember Email & Session Persistence Options
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Checkbox(
                          value: _rememberEmail,
                          onChanged: isLoading
                              ? null
                              : (val) {
                                  setState(() {
                                    _rememberEmail = val ?? false;
                                  });
                                },
                        ),
                        const Text('Remember email', style: TextStyle(fontSize: 13)),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Checkbox(
                          value: _rememberSession,
                          onChanged: isLoading
                              ? null
                              : (val) {
                                  setState(() {
                                    _rememberSession = val ?? false;
                                  });
                                },
                        ),
                        const Text('Stay signed in', style: TextStyle(fontSize: 13)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Sign In Button (disables duplicate submission and shows loading indicator)
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : _handleLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Sign In',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
                const SizedBox(height: 24),

                // Link to Sign Up
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text("Don't have an account? "),
                    TextButton(
                      onPressed: isLoading ? null : _navigateToSignUp,
                      child: const Text('Sign Up'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
