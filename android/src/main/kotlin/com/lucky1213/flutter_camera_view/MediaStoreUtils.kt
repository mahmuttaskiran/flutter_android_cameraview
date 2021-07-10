package com.lucky1213.flutter_camera_view

import android.content.ContentProvider
import android.content.ContentResolver
import android.content.ContentValues
import android.content.Context
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.provider.MediaStore
import android.webkit.MimeTypeMap
import java.io.File

class MediaStoreUtils {
    companion object{
        //针对非系统影音资源文件夹
        fun insertIntoMediaStore(context: Context, saveFile: File, isVideo: Boolean = false) {
            var createTime = System.currentTimeMillis()
            val contentResolver = context.contentResolver

            val values = ContentValues()
            values.put(MediaStore.MediaColumns.TITLE, saveFile.name)
            values.put(MediaStore.MediaColumns.DISPLAY_NAME, saveFile.name)
            //值一样，但是还是用常量区分对待
            values.put(
                if (isVideo) MediaStore.Video.VideoColumns.DATE_TAKEN else MediaStore.Images.ImageColumns.DATE_TAKEN,
                createTime
            )
            values.put(MediaStore.MediaColumns.DATE_MODIFIED, createTime)
            values.put(MediaStore.MediaColumns.DATE_ADDED, createTime)
            if (!isVideo) values.put(MediaStore.Images.ImageColumns.ORIENTATION, 0)
            values.put(MediaStore.MediaColumns.DATA, saveFile.absolutePath)
            values.put(MediaStore.MediaColumns.SIZE, saveFile.length())
            if (isVideo) values.put(MediaStore.MediaColumns.DURATION, getVideoDuration(saveFile.absolutePath))
            values.put(
                MediaStore.MediaColumns.MIME_TYPE,
                getMimeType(saveFile)
            )
            //插入
            contentResolver.insert(
                if (isVideo) MediaStore.Video.Media.EXTERNAL_CONTENT_URI else MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
                values
            )
        }

        private fun getMimeType(file: File): String? {
            var type: String? = null
            val url = file.toString()
            val extension = MimeTypeMap.getFileExtensionFromUrl(url)
            if (extension != null) {
                type = MimeTypeMap.getSingleton().getMimeTypeFromExtension(extension.toLowerCase())
            }
            if (type == null) {
                if (extension == "jpg" || extension == "jpeg") {
                    return "image/jpeg"
                } else if (extension == "png") {
                    return "image/png"
                } else if (extension == "mp4") {
                    return "video/mp4"
                }
                return type
            }
            return type
        }

        private fun getVideoDuration(path: String): Int {
            val media = MediaMetadataRetriever()
            media.setDataSource(path)

            var duration = media.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)

            return duration.toInt()
        }
    }

}