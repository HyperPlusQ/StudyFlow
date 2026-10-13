package com.hyperplusq.studyflow.system

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** 更新检查的版本比较：只有远端确实更新时才应提示“发现新版本”。 */
class GithubUpdateServiceTest {
    @Test
    fun newerPatchVersionIsDetected() {
        assertTrue(GithubUpdateService.isNewer("1.6.3", "1.6.2"))
    }

    @Test
    fun sameVersionIsNotNewer() {
        assertFalse(GithubUpdateService.isNewer("1.6.2", "1.6.2"))
    }

    @Test
    fun olderVersionIsNotNewer() {
        assertFalse(GithubUpdateService.isNewer("1.5.9", "1.6.2"))
    }

    @Test
    fun leadingVAndPrereleaseSuffixAreIgnored() {
        assertTrue(GithubUpdateService.isNewer("v1.7.0", "1.6.2"))
        assertTrue(GithubUpdateService.isNewer("1.6.2", "1.6.2-beta.3"))
        assertFalse(GithubUpdateService.isNewer("1.6.2-beta.3", "1.6.2"))
    }

    @Test
    fun numericComparisonHandlesMultipleDigits() {
        assertTrue(GithubUpdateService.isNewer("1.10.0", "1.9.9"))
        assertFalse(GithubUpdateService.isNewer("1.9.9", "1.10.0"))
    }
}
