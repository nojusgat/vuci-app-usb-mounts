<template>
  <a-modal
    :title="mountpoint + path"
    :visible="visible"
    @cancel="$emit('cancel')"
    :footer="false"
  >
    <a-table :columns="columns" :data-source="data" :loading="loading" :showHeader="false">
      <div
        slot="name"
        slot-scope="file"
        @click="changePath(file)"
        :class="[{ 'drop': dragged === file.name }, file.type]"
        @dragover.prevent="onEnterDrag(file)"
        @dragenter.prevent="onEnterDrag(file)"
        @dragleave.prevent="onLeaveDrag"
        @dragend.prevent="onLeaveDrag"
        @drop.prevent="onDrop($event, file)"
      >
        <div class="item">
          <a-icon :type="getIcon(file)" style="font-size: 30px" />
          <span>{{ file.name }}</span>
        </div>
      </div>
      <div slot="action" class="action" slot-scope="file" v-if="file.name !== '..'">
        <a-tooltip v-if="file.type !== 'directory'">
          <template slot="title">
            Download
          </template>
          <a-button type="primary" size="small" icon="download" @click="downloadFile(file)" />
        </a-tooltip>
        <a-tooltip>
          <template slot="title">
            Delete
          </template>
          <a-button type="danger" size="small" icon="delete" @click="deleteFile(file)" />
        </a-tooltip>
      </div>
    </a-table>
    <a-space>
      <a-button icon="folder" @click="createDirectory">
        Create directory
      </a-button>
      <upload-button ref="upload" :mountpoint="mountpoint" :path="path" :files="data" @refresh="getFiles" @status="changeUploadStatus" />
    </a-space>
    <form ref="download" method="POST" action="/download">
      <input v-show="false" type="text" :value="downloadPath" name="path"/>
      <input v-show="false" type="text" :value="downloadFilename" name="filename"/>
    </form>
  </a-modal>
</template>

<script>
import UploadButton from './UploadButton.vue'

export default {
  name: 'BrowserModal',
  components: {
    UploadButton
  },
  data () {
    return {
      data: [],
      columns: [
        { title: 'name', scopedSlots: { customRender: 'name' } },
        { title: 'action', scopedSlots: { customRender: 'action' } }
      ],
      loading: true,
      path: '/',
      downloadPath: '',
      downloadFilename: '',
      dragged: '',
      uploadStatus: ''
    }
  },
  props: {
    visible: {
      type: Boolean,
      default: false
    },
    device: {
      type: String,
      default: null
    },
    mountpoint: {
      type: String,
      default: null
    },
    devices: {
      type: Array,
      default: () => []
    }
  },
  methods: {
    resetData () {
      this.loading = true
      this.data = []
      this.path = '/'
      this.downloadPath = ''
      this.downloadFilename = ''
    },
    getFiles () {
      this.$rpc
        .call('mounts', 'files', { device: this.device, path: this.path })
        .then(data => {
          const copy = data
            .sort((a, b) => a.type.localeCompare(b.type) || a.name.localeCompare(b.name))
          if (this.path !== '/') {
            copy.unshift({
              name: '..',
              path: this.previousPath,
              type: 'directory'
            })
          }
          this.data = copy.map((v, i) => {
            v.key = i
            return v
          })
        })
        .finally(() => {
          this.loading = false
        })
    },
    getIcon (file) {
      if (file.name === '..') return 'rollback'
      if (file.type === 'directory' && file.name === this.dragged) return 'folder-open'
      if (file.type === 'directory') return 'folder'
      return 'file'
    },
    changePath (file) {
      if (file.type !== 'directory') return
      this.path = file.path
    },
    downloadFile (file) {
      this.downloadPath = this.mountpoint + this.path + file.name
      this.downloadFilename = file.name

      const hideLoading = this.$message.loading('Preparing download...', 0)
      setTimeout(() => {
        hideLoading()
        this.$refs.download.submit()
      }, 1000)
    },
    createDirectory () {
      this.$prompt({
        title: 'Create directory',
        placeholder: 'Enter directory name',
        validator: value => {
          if (value.match(/^[a-zA-Z0-9_]+$/) === null) {
            return 'Invalid directory name'
          }

          if (this.data.filter(data => data.name === value).length > 0) {
            return 'Directory with this name already exists'
          }
        }
      })
        .then((value) =>
          this.$rpc.call('mounts', 'create', {
            type: 'directory',
            device: this.device,
            path: this.path,
            name: value
          })
        )
        .then(resp => {
          if (!resp.success) return this.$message.error('Failed to create directory')

          this.$message.success('Directory created')
          this.getFiles()
        })
        .catch(() => {})
    },
    deleteFile (file) {
      const type = file.type.charAt(0).toUpperCase() + file.type.slice(1)
      this.$confirm({
        title: 'Are you sure?',
        content: `${type} '${file.name}' will be deleted`,
        onOk: () => {
          this.$rpc
            .call('mounts', 'delete', {
              device: this.device,
              path: this.path,
              name: file.name
            })
            .then(res => {
              if ('message' in res && res.message === 'Directory not empty') return this.forceDeleteDirectory(file)
              if (!res.success) throw Error(`Failed to delete ${file.type} '${file.name}'`)

              this.$message.success(`${type} '${file.name}' deleted`)
              this.getFiles()
            })
            .catch(err => {
              this.$message.error(err.message || 'Something went wrong')
            })
        }
      })
    },
    forceDeleteDirectory (file) {
      const type = file.type.charAt(0).toUpperCase() + file.type.slice(1)
      this.$confirm({
        title: 'Directory is not empty! Are you sure?',
        content: `${type} '${file.name}' and all its content will be deleted`,
        onOk: () => {
          this.$rpc
            .call('mounts', 'delete', {
              device: this.device,
              path: this.path,
              name: file.name,
              force: true
            })
            .then(res => {
              if (!res.success) throw Error(`Failed to delete ${file.type} '${file.name}'`)

              this.$message.success(`${type} '${file.name}' and all of its content deleted`)
              this.getFiles()
            })
            .catch(err => {
              this.$message.error(err.message || 'Something went wrong')
            })
        }
      })
    },
    onDrop (event, file) {
      this.dragged = ''

      const files = event.dataTransfer.files
      if (files.length === 0) return
      if (files.length > 1) return this.$message.error('You can not upload more than one file')
      if (this.uploadStatus === 'uploading') return this.$message.error('Please wait until upload is finished')

      this.isFile(files[0]).then(isFile => {
        if (!isFile) return this.$message.error('You can only upload files')
        this.$refs.upload.onFileDrop(event, file.path)
      })
    },
    onEnterDrag (file) {
      this.dragged = file.name
    },
    onLeaveDrag () {
      this.dragged = ''
    },
    isFile (file) {
      return new Promise(resolve => {
        var fr = new FileReader()
        fr.onload = () => {
          resolve(true)
        }
        fr.onerror = () => {
          resolve(false)
        }
        fr.readAsText(file)
      })
    },
    changeUploadStatus (status) {
      this.uploadStatus = status
    }
  },
  computed: {
    previousPath () {
      return this.path.substring(0, this.path.lastIndexOf('/', this.path.lastIndexOf('/') - 1)) + '/'
    }
  },
  watch: {
    visible (newValue) {
      if (newValue !== true) return
      this.resetData()
      this.getFiles()
    },
    path () {
      this.getFiles()
    },
    devices (newArray) {
      if (newArray.some(data => data.mountpoint === this.mountpoint)) return
      this.$emit('cancel')
    }
  }
}
</script>

<style scoped>
.directory {
  cursor: pointer;
}

.file {
  cursor: initial;
}

.item {
  display: flex;
  flex-direction: row;
  align-items: center;
  gap: 10px;
}

.directory.drop {
  background-color: #f9f9f9;
  border: #dddddd 2px dashed;
  border-radius: 10px;
  padding: 5px;
}

.file.drop {
  background-color: #f9f9f9;
  border: #f9f9f9 2px solid;
  border-radius: 10px;
  padding: 5px;
}

.action {
  display: flex;
  justify-content: flex-end;
  gap: 5px;
}
</style>
