<template>
  <a-upload
    name="file"
    action="/upload"
    @change="onUpload"
    :data="{ path: path + fileName }"
    :beforeUpload="beforeUpload"
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
      upload: true
    }
  },
  props: {
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

      if (this.files.filter(data => data.name === file.name).length > 0) {
        this.upload = false
        this.$message.error(`File with the name '${file.name}' aready exists.`)
        return false
      }
    },
    onUpload (info) {
      const file = info.file
      const status = file.status

      if (status === 'uploading' || status === 'removed') return

      info.fileList.length = 0

      if (this.upload === false) return

      if (status !== 'done') {
        this.$message.error(`Upload '${this.fileName}' failed.`)
        return
      }

      this.$message.success(`File '${this.fileName}' uploaded.`)
      this.$emit('refresh')
    }
  }
}
</script>
