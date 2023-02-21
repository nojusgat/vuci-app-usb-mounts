<template>
  <a-upload
    name="file"
    action="/upload"
    @change="onUpload"
    :data="{ path: mountpoint + internalPath + fileName }"
    :beforeUpload="beforeUpload"
    ref="upload"
    :disabled="status === 'uploading'"
  >
    <a-button icon="upload">Upload file</a-button>
  </a-upload>
</template>

<script>
export default {
  name: 'UploadButton',
  data () {
    return {
      fileName: '',
      upload: true,
      internalPath: '',
      status: ''
    }
  },
  props: {
    mountpoint: {
      type: String,
      default: ''
    },
    path: {
      type: String,
      default: ''
    },
    files: {
      type: Array,
      default: () => []
    }
  },
  methods: {
    beforeUpload (file) {
      this.upload = true
      this.fileName = file.name

      if (this.files.filter(data => data.name === file.name && data.path === this.internalPath).length > 0) {
        this.upload = false
        this.$message.error(`File with the name '${file.name}' aready exists.`)
        this.internalPath = this.path
        return false
      }
    },
    onUpload (info) {
      const file = info.file
      const status = file.status

      this.status = status
      this.$emit('status', status)

      if (status === 'uploading' || status === 'removed') return

      info.fileList.length = 0

      if (this.upload === false) return

      if (status !== 'done') {
        this.$message.error(`Upload '${this.fileName}' failed.`)
        this.internalPath = this.path
        return
      }

      this.$message.success(`File '${this.fileName}' uploaded to '${this.mountpoint + this.internalPath}'.`)
      this.internalPath = this.path
      this.$emit('refresh')
    },
    onFileDrop (event, path) {
      this.internalPath = path
      this.$refs.upload.$refs.uploadRef.$refs.uploaderRef.onFileDrop(event)
    }
  },
  watch: {
    path (value) {
      this.internalPath = value
    }
  }
}
</script>
