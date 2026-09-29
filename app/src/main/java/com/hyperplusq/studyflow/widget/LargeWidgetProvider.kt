package com.hyperplusq.studyflow.widget

import com.hyperplusq.studyflow.R

class LargeWidgetProvider : StudyFlowWidgetProvider() {
    override val layoutRes: Int = R.layout.widget_large_4x4
    override val maxItems: Int = 5
}
