package com.hyperplusq.studyflow.ui

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.lifecycle.viewmodel.compose.viewModel
import com.hyperplusq.studyflow.ui.theme.StudyFlowTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        AppApplication.instance = application
        enableEdgeToEdge()
        setContent {
            StudyFlowTheme {
                val viewModel: AppViewModel = viewModel(factory = AppViewModel.Factory)
                StudyFlowAppUi(viewModel)
            }
        }
    }
}
