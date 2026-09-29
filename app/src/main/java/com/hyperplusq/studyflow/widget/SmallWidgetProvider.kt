package com.hyperplusq.studyflow.widget

import com.hyperplusq.studyflow.R

class SmallWidgetProvider : StudyFlowWidgetProvider() {
    override val layoutRes: Int = R.layout.widget_small_2x2
    override val maxItems: Int = 1
}
