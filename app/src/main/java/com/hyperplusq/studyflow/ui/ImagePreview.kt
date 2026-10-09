package com.hyperplusq.studyflow.ui

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.gestures.detectTransformGestures
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Close
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import com.hyperplusq.studyflow.data.db.AttachmentEntity

/**
 * 图片预览状态由应用根组件持有，通过 CompositionLocal 提供给列表、详情与编辑器，
 * 使任何位置的附件缩略图都能打开同一个全屏预览窗口。
 */
class ImagePreviewState {
    var attachment by mutableStateOf<AttachmentEntity?>(null)
        private set

    fun show(attachment: AttachmentEntity) {
        this.attachment = attachment
    }

    fun dismiss() {
        attachment = null
    }
}

val LocalImagePreviewState = staticCompositionLocalOf<ImagePreviewState?> { null }

/** 返回打开全屏图片预览的回调；未提供宿主状态时为空操作。 */
@Composable
fun rememberImagePreviewLauncher(): (AttachmentEntity) -> Unit {
    val state = LocalImagePreviewState.current
    return { attachment -> state?.show(attachment) }
}

/** 独立系统窗口中的图片预览：黑底、双指缩放、双击放大、右上角关闭按钮。 */
@Composable
fun ImagePreviewOverlay(state: ImagePreviewState) {
    val attachment = state.attachment ?: return
    Dialog(
        onDismissRequest = { state.dismiss() },
        properties = DialogProperties(
            usePlatformDefaultWidth = false,
            decorFitsSystemWindows = false
        )
    ) {
        ImagePreviewContent(
            attachment = attachment,
            onDismiss = { state.dismiss() }
        )
    }
}

@Composable
private fun ImagePreviewContent(
    attachment: AttachmentEntity,
    onDismiss: () -> Unit
) {
    BoxWithConstraints(
        Modifier
            .fillMaxSize()
            .background(Color.Black)
    ) {
        val state by rememberAttachmentPreviewImage(attachment)

        var scale by remember(attachment.id) { mutableFloatStateOf(1f) }
        var offset by remember(attachment.id) { mutableStateOf(Offset.Zero) }

        when (val current = state) {
            DecodedImage.Loading -> CircularProgressIndicator(
                modifier = Modifier.align(Alignment.Center),
                color = Color.White,
                strokeWidth = 3.dp
            )

            DecodedImage.Failed -> Text(
                "无法加载图片",
                color = Color.White,
                style = MaterialTheme.typography.bodyLarge,
                modifier = Modifier.align(Alignment.Center)
            )

            is DecodedImage.Ready -> {
                val density = LocalDensity.current
                val boxWidthPx = with(density) { maxWidth.toPx() }
                val boxHeightPx = with(density) { maxHeight.toPx() }
                val ratio = current.bitmap.width.toFloat() / current.bitmap.height.toFloat()
                val fitWidthPx = if (boxWidthPx / ratio <= boxHeightPx) {
                    boxWidthPx
                } else {
                    boxHeightPx * ratio
                }
                val fitHeightPx = fitWidthPx / ratio

                Image(
                    bitmap = current.bitmap.asImageBitmap(),
                    contentDescription = attachment.fileName,
                    contentScale = ContentScale.Fit,
                    modifier = Modifier
                        .fillMaxSize()
                        .graphicsLayer {
                            scaleX = scale
                            scaleY = scale
                            translationX = offset.x
                            translationY = offset.y
                        }
                        .pointerInput(attachment.id, boxWidthPx, boxHeightPx) {
                            detectTransformGestures { _, pan, zoom, _ ->
                                val newScale = (scale * zoom).coerceIn(1f, 6f)
                                scale = newScale
                                if (newScale <= 1.01f) {
                                    offset = Offset.Zero
                                } else {
                                    val limitX = ((fitWidthPx * newScale) - boxWidthPx)
                                        .coerceAtLeast(0f) / 2f
                                    val limitY = ((fitHeightPx * newScale) - boxHeightPx)
                                        .coerceAtLeast(0f) / 2f
                                    offset = Offset(
                                        (offset.x + pan.x).coerceIn(-limitX, limitX),
                                        (offset.y + pan.y).coerceIn(-limitY, limitY)
                                    )
                                }
                            }
                        }
                        .pointerInput(attachment.id) {
                            detectTapGestures(
                                onDoubleTap = {
                                    if (scale > 1f) {
                                        scale = 1f
                                        offset = Offset.Zero
                                    } else {
                                        scale = 2.5f
                                    }
                                }
                            )
                        }
                )
            }
        }

        IconButton(
            onClick = onDismiss,
            modifier = Modifier
                .align(Alignment.TopEnd)
                .padding(top = 14.dp, end = 16.dp)
                .size(42.dp)
                .background(Color.Black.copy(alpha = 0.48f), CircleShape)
        ) {
            Icon(
                Icons.Outlined.Close,
                contentDescription = "关闭图片预览",
                tint = Color.White,
                modifier = Modifier.size(22.dp)
            )
        }
    }
}
