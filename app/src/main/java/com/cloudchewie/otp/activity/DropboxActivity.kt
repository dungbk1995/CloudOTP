package com.cloudchewie.otp.activity

import android.annotation.SuppressLint
import android.content.Context
import android.content.SharedPreferences
import android.os.Bundle
import android.util.Log
import android.view.View
import android.widget.Toast
import com.blankj.utilcode.util.ThreadUtils
import com.cloudchewie.otp.databinding.ActivityDropboxBinding
import com.cloudchewie.otp.external.AESStringCypher
import com.cloudchewie.otp.external.AccessTokenManager
import com.cloudchewie.otp.external.DropboxAccountTask
import com.cloudchewie.otp.external.DropboxClient
import com.cloudchewie.otp.external.DropboxDownloadTask
import com.cloudchewie.otp.external.DropboxFileTask
import com.cloudchewie.otp.external.DropboxUploadTask
import com.cloudchewie.otp.external.Utils
import com.cloudchewie.otp.widget.SetSecretBottomSheet
import com.cloudchewie.ui.custom.IToast
import com.cloudchewie.util.ui.StatusBarUtil
import com.dropbox.core.android.Auth
import com.dropbox.core.v2.files.FileMetadata
import com.dropbox.core.v2.files.SearchV2Result
import com.dropbox.core.v2.users.FullAccount
import com.google.gson.Gson
import com.google.gson.reflect.TypeToken
import java.io.File
import java.io.FileInputStream
import java.io.IOException
import java.io.UnsupportedEncodingException
import java.security.GeneralSecurityException

open class DropboxActivity : BaseActivity(), SetSecretBottomSheet.OnConfirmListener {

    private var accessToken: String? = null
    private var accessTokenManager: AccessTokenManager? = null
    private var prefs: SharedPreferences? = null
    private val dropboxClient: DropboxClient? = null
    private var mEncryptedFile: File? = null
    private var hasRemoteFile = false
    private lateinit var binding: ActivityDropboxBinding

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityDropboxBinding.inflate(layoutInflater)
        setContentView(binding.root)
        StatusBarUtil.setStatusBarMarginTop(this)

        binding.activityDropboxEmail.setDisabled(true)
        binding.activityDropboxNickname.setDisabled(true)

        accessTokenManager = AccessTokenManager(applicationContext)

        binding.syncTokenButton.setOnClickListener(mSyncButtonListener)
        binding.syncTokenButton.visibility = View.INVISIBLE

        binding.signInButton.setOnClickListener {
            Auth.startOAuth2Authentication(
                this, "ljyx5bk2jq92esr"
            )
        }

        binding.activityDropboxSwipeRefresh.setEnableOverScrollDrag(true)
        binding.activityDropboxSwipeRefresh.setEnableOverScrollBounce(true)
        binding.activityDropboxSwipeRefresh.setEnableLoadMore(false)
        binding.activityDropboxSwipeRefresh.setEnablePureScrollMode(true)
    }

    override fun onResume() {
        super.onResume()
        getAccessToken()
    }

    private val mSyncButtonListener = View.OnClickListener {
        val bottomSheet = SetSecretBottomSheet(applicationContext, hasRemoteFile)
        bottomSheet.show()
    }

    private fun getAccessToken() {
        if (accessTokenManager!!.haveToken()) {
            accessToken = accessTokenManager!!.token
            getAccount()
        } else {
            val accessToken = Auth.getOAuth2Token()
            if (accessToken != null) {
                accessTokenManager!!.token = accessToken
                this.accessToken = accessToken
                getAccount()
            }
        }
    }

    private fun getAccount() {
        if (accessToken == null) return
        ThreadUtils.executeBySingle(
            DropboxAccountTask(
                DropboxClient.getClient(accessToken!!),
                object : DropboxAccountTask.TaskDelegate {
                    @SuppressLint("SetTextI18n")
                    override fun onAccountReceived(account: FullAccount) {
                        binding.activityDropboxEmail.editText.setText(account.email)
                        binding.activityDropboxNickname.editText.setText(account.name.displayName)
                        binding.signInButton.visibility = View.GONE
                        locateFile()
                    }

                    override fun onError(error: Exception?) {
                        Log.d("Dropbox", "Get Account Error")
                    }
                },
            )
        )
    }

    private fun locateFile() {
        ThreadUtils.executeBySingle(
            DropboxFileTask(
                DropboxClient.getClient(accessToken!!), object : DropboxFileTask.Callback {
                    override fun onGetListResults(list: SearchV2Result) {
                        if (list.matches.size > 0) {
                            val fileMetadata =
                                list.matches[0].metadata.metadataValue as FileMetadata
                            hasRemoteFile = true
                            downloadFile(fileMetadata)
                        } else {
                            hasRemoteFile = false
                        }
                        binding.syncTokenButton.visibility = View.VISIBLE
                    }

                    override fun onError(error: Exception?) {
                        Log.d("Dropbox", "Locate File Error")
                    }
                }, FILENAME
            )
        )
    }

    private fun downloadFile(fileMetadata: FileMetadata) {
        ThreadUtils.executeBySingle(
            DropboxDownloadTask(
                DropboxClient.getClient(accessToken!!), object : DropboxDownloadTask.Callback {
                    override fun onDownloadComplete(result: File) {
                        mEncryptedFile = result
                    }

                    override fun onError(e: Exception?) {
                        Log.d("Dropbox", "Download File ${fileMetadata.name} Error")
                    }
                }, this.applicationContext, fileMetadata
            )
        )
    }

    private fun uploadFile() {
        ThreadUtils.executeBySingle(mEncryptedFile?.let {
            DropboxUploadTask(
                this.applicationContext,
                DropboxClient.getClient(accessToken!!),
                object : DropboxUploadTask.Callback {

                    override fun onUploadcomplete(result: FileMetadata) {
                        IToast.showBottom(applicationContext, "同步成功")
                        hasRemoteFile = true
                    }

                    override fun onError(ex: Exception?) {
                        Log.d("Dropbox", "Upload File ${mEncryptedFile?.name} Error")
                    }
                },
                it
            )
        })
    }

    override fun onPasswordSet(password: String) {
        val gson = Gson()
        prefs = applicationContext.getSharedPreferences("tokens", Context.MODE_PRIVATE)
        if (hasRemoteFile) {
            val fileLength = mEncryptedFile!!.length().toInt()
            val bytes = ByteArray(fileLength)

            try {
                val inputFile = FileInputStream(mEncryptedFile!!)
                inputFile.read(bytes)
                val contents = String(bytes)
                //Log.d("FileRead", contents);
                val cypher = AESStringCypher.CipherTextIvMac(contents)
                val keys = AESStringCypher.generateKeyFromPassword(password, password)
                val decrypted = AESStringCypher.decryptString(cypher, keys)
                if (decrypted.contains("{}")) {
                    Toast.makeText(this, "没有Keys", Toast.LENGTH_LONG).show()
                } else {
                    val back = Utils.transformJsonToStringHashMap(decrypted)
                    val remoteDate = java.lang.Long.parseLong(back["lastModified"])
                    val localDate =
                        java.lang.Long.parseLong(prefs!!.getString("lastModified", "-1"))
                    //Log.d("DATES:", "REMOTE DATE = " + remoteDate + " LOCALDATE = " + localDate + " REMOTE NEWER? " + Utils.isRemoteDateNewer(localDate, remoteDate));
                    if (Utils.isRemoteDateNewer(localDate, remoteDate)) {
                        Utils.overwriteAndroidSharedPrefereces(back, prefs)
                        Toast.makeText(this, "本地同步成功", Toast.LENGTH_SHORT).show()

                    } else {
                        val encrypted = encryptSharedPrefs(password, gson)
                        mEncryptedFile = Utils.createCachedFileFromTokenString(
                            encrypted, FILENAME, applicationContext
                        )
                        uploadFile()
                        Toast.makeText(this, "远端同步成功", Toast.LENGTH_SHORT).show()

                    }
                }

            } catch (ex: IOException) {
                ex.printStackTrace()
            } catch (ex: GeneralSecurityException) {
                //Log.d("Decrypt", "Wrong password");
                Toast.makeText(this, "同步密码错误", Toast.LENGTH_SHORT).show()
            }


        } else {
            try {
                val encrypted = encryptSharedPrefs(password, gson)
                Log.d("ENCRYPTED", encrypted)
                mEncryptedFile =
                    Utils.createCachedFileFromTokenString(encrypted, FILENAME, applicationContext)
                uploadFile()
            } catch (e: Exception) {
                e.printStackTrace()
            }

        }
    }

    @Throws(UnsupportedEncodingException::class, GeneralSecurityException::class)
    private fun encryptSharedPrefs(password: String, gson: Gson): String {
        val tokens = prefs!!.all as HashMap<*, *>
        //Log.d("Tokens", Integer.toString(tokens.size()));
        val hashmapStringType = object : TypeToken<HashMap<String, String>>() {}.type
        val json = gson.toJson(tokens, hashmapStringType)
        //Log.d("JSON", json);
        val keys = AESStringCypher.generateKeyFromPassword(password, password)
        val toencrypt = AESStringCypher.encrypt(json, keys)
        return toencrypt.toString()
    }

    companion object {
        private const val FILENAME = "CloudOTP.db"
    }
}
