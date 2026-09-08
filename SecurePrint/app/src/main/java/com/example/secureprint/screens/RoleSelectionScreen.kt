package com.example.secureprint.screens

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.example.secureprint.R
import com.example.secureprint.components.RoleCard
import com.example.secureprint.ui.theme.SecurePrintTheme

@Composable
fun RoleSelectionScreen(
    onRoleSelected: (String) -> Unit,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier
            .fillMaxSize()
            .padding(24.dp)
            .verticalScroll(rememberScrollState()),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Top
    ) {
        Spacer(modifier = Modifier.height(40.dp))

        Text(
            text = stringResource(R.string.choose_role),
            style = MaterialTheme.typography.displaySmall,
            fontWeight = FontWeight.Bold,
            color = MaterialTheme.colorScheme.primary
        )

        Spacer(modifier = Modifier.height(32.dp))

        RoleCard(
            title = stringResource(R.string.customer),
            description = stringResource(R.string.customer_desc),
            icon = "👤",
            onClick = { onRoleSelected("customer") }
        )

        Spacer(modifier = Modifier.height(16.dp))

        RoleCard(
            title = stringResource(R.string.xerox_shop),
            description = stringResource(R.string.xerox_shop_desc),
            icon = "🏪",
            onClick = { onRoleSelected("shop") }
        )

        Spacer(modifier = Modifier.height(16.dp))

        RoleCard(
            title = stringResource(R.string.admin),
            description = stringResource(R.string.admin_desc),
            icon = "⚙️",
            onClick = { onRoleSelected("admin") }
        )
    }
}

@Preview(showBackground = true)
@Composable
fun RoleSelectionScreenPreview() {
    SecurePrintTheme {
        RoleSelectionScreen(onRoleSelected = {})
    }
}
