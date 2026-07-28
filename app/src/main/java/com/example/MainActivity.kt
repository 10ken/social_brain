package com.example

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.viewModels
import androidx.compose.foundation.layout.fillMaxSize
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.compose.material3.Surface
import androidx.compose.ui.Modifier
import com.example.ui.AppViewModel
import com.example.ui.screens.MainAppContainer
import com.example.ui.theme.MyApplicationTheme
import com.example.api.SecureAiGateway

class MainActivity : ComponentActivity() {
    private val viewModel: AppViewModel by viewModels()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        SecureAiGateway.initializeAppCheck()
        enableEdgeToEdge()
        setContent {
            val appSettings = viewModel.appSettings.collectAsStateWithLifecycle()
            val themeMode = appSettings.value?.themeMode ?: "DARK"
            
            MyApplicationTheme(themeMode = themeMode) {
                Surface(
                    modifier = Modifier.fillMaxSize(),
                    color = com.example.ui.theme.Slate900
                ) {
                    MainAppContainer(viewModel = viewModel)
                }
            }
        }
    }
}
