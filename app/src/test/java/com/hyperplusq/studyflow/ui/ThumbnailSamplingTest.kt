package com.hyperplusq.studyflow.ui

import com.hyperplusq.studyflow.data.db.AttachmentEntity
import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * 缩略图解码采样率与缓存键的静态校验：
 * 采样率决定列表解码开销与内存占用，缓存键决定是否会重复遍历图片字节。
 */
class ThumbnailSamplingTest {
    @Test
    fun imageWithinLimitIsNotDownSampled() {
        assertEquals(1, sampleSizeFor(300, 200, 320))
        assertEquals(1, sampleSizeFor(320, 320, 320))
    }

    @Test
    fun oversizeImageIsHalvedUntilWithinLimit() {
        assertEquals(2, sampleSizeFor(640, 480, 320))
        assertEquals(4, sampleSizeFor(1000, 800, 320))
        assertEquals(8, sampleSizeFor(1300, 1000, 320))
    }

    @Test
    fun samplingUsesLongestEdge() {
        assertEquals(4, sampleSizeFor(200, 1000, 320))
        assertEquals(4, sampleSizeFor(1000, 200, 320))
        assertEquals(2, sampleSizeFor(500, 300, 320))
    }

    @Test
    fun invalidInputsFallBackToFullResolution() {
        assertEquals(1, sampleSizeFor(0, 0, 320))
        assertEquals(1, sampleSizeFor(-1, 100, 320))
        assertEquals(1, sampleSizeFor(1000, 1000, 0))
    }

    @Test
    fun cacheKeyTracksIdentityAndPayloadSizeWithoutHashingBytes() {
        val base = AttachmentEntity(
            id = 7,
            assignmentId = 1,
            fileName = "a.jpg",
            imageData = byteArrayOf(1, 2, 3)
        )
        val replaced = base.copy(id = 8, imageData = byteArrayOf(1, 2, 3, 4))

        assertEquals("7:3", attachmentCacheKey(base))
        assertEquals("8:4", attachmentCacheKey(replaced))
    }
}
