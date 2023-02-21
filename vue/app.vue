<template>
  <div>
    <a-table :columns="columns" :data-source="devices" :loading="loading">
      <div slot="memory" slot-scope="size">
        <a-progress type="circle" :percent="(size.used / size.total) * 100" :width="90">
          <template #format>
            <div>{{ '%mB'.format(size.used) }}</div>
            <small>{{ '%mB'.format(size.total) }}</small>
          </template>
        </a-progress>
      </div>
      <div slot="actions" slot-scope="data">
        <a-space>
          <a-button type="primary" icon="folder-open" @click="openBrowse(data)">
            Browse
          </a-button>
          <a-button type="danger" icon="usb" @click="unmount(data.mountpoint)">
            Unmount
          </a-button>
        </a-space>
      </div>
    </a-table>
    <browser-modal :key="browse.mountpoint" v-bind="browse" :devices="devices" @cancel="browse.visible = false" />
  </div>
</template>

<script>
import BrowserModal from './components/BrowserModal.vue'

export default {
  components: {
    BrowserModal
  },
  data () {
    return {
      loading: true,
      columns: [
        { dataIndex: 'mountpoint', title: 'Mountpoint' },
        { dataIndex: 'device', title: 'Device' },
        { dataIndex: 'filesystem', title: 'Filesystem' },
        { dataIndex: 'size', title: 'Used memory', scopedSlots: { customRender: 'memory' } },
        { key: 'actions', title: '', scopedSlots: { customRender: 'actions' } }
      ],
      devices: [],
      browse: {
        visible: false,
        device: null,
        mountpoint: null
      }
    }
  },
  methods: {
    getDevices () {
      this.$rpc
        .call('mounts', 'devices')
        .then(data => {
          this.devices = data.map((v, i) => {
            v.key = i
            return v
          })
        })
        .finally(() => {
          this.loading = false
        })
    },
    unmount (mountpoint) {
      this.$confirm({
        title: 'Are you sure?',
        content: mountpoint + ' will be unmounted',
        onOk: () => {
          this.$rpc
            .call('mounts', 'unmount', { mountpoint })
            .then(res => {
              if (!res.success) throw Error('Failed to unmount')
              this.$message.success(mountpoint + ' unmounted')
            })
            .catch(err => {
              this.$message.error(err.message || 'Something went wrong')
            })
            .finally(() => {
              this.$timer.stop('getDevices')
              this.$timer.start('getDevices')
            })
        }
      })
    },
    openBrowse (data) {
      this.browse.visible = true
      this.browse.device = data.device
      this.browse.mountpoint = data.mountpoint
    }
  },
  timers: {
    getDevices: { time: 5000, autostart: true, immediate: true, repeat: true }
  }
}
</script>
