<template>
  <div class="p-6 space-y-6">
    <div class="card bg-base-100 shadow">
      <div class="card-body">
        <h2 class="card-title">用户管理</h2>
        <form class="grid grid-cols-1 md:grid-cols-4 gap-3" @submit.prevent="saveUser">
          <input class="input input-bordered" v-model="form.username" :disabled="form.protected" placeholder="登录名" />
          <input class="input input-bordered" type="password" v-model="form.password" :placeholder="isEditing ? '留空不修改密码' : '密码'" />
          <select class="select select-bordered" v-model="form.role" :disabled="form.protected">
            <option value="user">普通用户</option>
            <option value="admin">管理员</option>
          </select>
          <input class="input input-bordered" v-model="form.contactName" placeholder="联系人" />
          <input class="input input-bordered" v-model="form.phone" placeholder="联系电话" />
          <input class="input input-bordered" v-model="form.email" placeholder="邮箱" />
          <div class="flex gap-2">
            <button class="btn btn-primary" type="submit">{{ isEditing ? '保存' : '新增用户' }}</button>
            <button class="btn btn-ghost" type="button" @click="resetForm">重置</button>
          </div>
        </form>
      </div>

      <div class="overflow-x-auto">
        <table class="table table-zebra">
          <thead>
            <tr>
              <th>ID</th>
              <th>登录名</th>
              <th>角色</th>
              <th>联系人</th>
              <th>电话</th>
              <th>邮箱</th>
              <th>操作</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="u in users" :key="u.id">
              <td>{{ u.id }}</td>
              <td>{{ u.username }}</td>
              <td>{{ u.role }}</td>
              <td>{{ u.contactName || '-' }}</td>
              <td>{{ u.phone || '-' }}</td>
              <td>{{ u.email || '-' }}</td>
              <td class="space-x-2">
                <button class="btn btn-xs btn-ghost" @click="editUser(u)">编辑</button>
                <button class="btn btn-xs btn-outline btn-error" :disabled="u.username === 'admin'" @click="deleteUser(u)">删除</button>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>

    <div class="card bg-base-100 shadow">
      <div class="card-body">
        <h2 class="card-title">打印记录</h2>
        <div class="flex flex-wrap gap-3 items-end">
          <input class="input input-bordered" v-model="printFilters.username" placeholder="用户名" />
          <input class="input input-bordered" type="date" v-model="printFilters.start" />
          <input class="input input-bordered" type="date" v-model="printFilters.end" />
          <button class="btn btn-outline" @click="loadPrintRecords">查询</button>
        </div>
      </div>
      <div class="overflow-x-auto">
        <table class="table table-zebra">
          <thead>
            <tr>
              <th>时间</th>
              <th>用户</th>
              <th>文件</th>
              <th>页数</th>
              <th>状态</th>
              <th>下载</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="rec in printRecords" :key="rec.id">
              <td>{{ rec.createdAt }}</td>
              <td>{{ rec.username }}</td>
              <td>{{ rec.filename }}</td>
              <td>{{ rec.pages }}</td>
              <td>{{ rec.status }}</td>
              <td>
                <a class="link" :href="`/api/print-records/${rec.id}/file`" target="_blank">下载</a>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>

    <div class="card bg-base-100 shadow">
      <div class="card-body">
        <h2 class="card-title">系统设置</h2>
        <div class="grid grid-cols-1 md:grid-cols-4 gap-3 items-end">
          <label class="form-control">
            <div class="label">
              <span class="label-text">自动清理天数</span>
            </div>
            <input class="input input-bordered" type="number" step="1" v-model="settings.retentionDays" placeholder="例如 30" />
          </label>
          <div class="flex items-end">
            <button class="btn btn-primary" @click="saveSettings">保存设置</button>
          </div>
        </div>
        <div class="text-sm text-muted mt-2">自动清理会删除打印记录与文件，并压缩数据库。</div>
        <div class="text-sm text-muted mt-1">SESSION_HASH_KEY / SESSION_BLOCK_KEY 通过环境变量配置，未设置会自动生成（仅建议测试环境）。</div>
      </div>
    </div>
  </div>
</template>

<script>
export default {
  data() {
    return {
      users: [],
      form: {
        id: null,
        username: '',
        password: '',
        role: 'user',
        protected: false,
        contactName: '',
        phone: '',
        email: ''
      },
      printFilters: { username: '', start: '', end: '' },
      printRecords: [],
      settings: { retentionDays: '' }
    }
  },
  computed: {
    isEditing() {
      return !!this.form.id
    }
  },
  async mounted() {
    await this.loadUsers()
    await this.loadPrintRecords()
    await this.loadSettings()
  },
  methods: {
    getCSRF() {
      const m = document.cookie.match('(^|;)\\s*csrf_token\\s*=\\s*([^;]+)')
      return m ? m.pop() : ''
    },
    async readError(resp) {
      try {
        const data = await resp.json()
        return data.error || resp.statusText
      } catch (e) {
        try {
          const text = await resp.text()
          return text || resp.statusText
        } catch (err) {
          return resp.statusText
        }
      }
    },
    resetForm() {
      this.form = {
        id: null,
        username: '',
        password: '',
        role: 'user',
        protected: false,
        contactName: '',
        phone: '',
        email: ''
      }
    },
    editUser(user) {
      this.form = {
        id: user.id,
        username: user.username,
        password: '',
        role: user.role,
        protected: user.username === 'admin',
        contactName: user.contactName || '',
        phone: user.phone || '',
        email: user.email || ''
      }
    },
    async loadUsers() {
      const resp = await fetch('/api/admin/users', { credentials: 'include' })
      if (!resp.ok) {
        if (resp.status === 401) this.$emit('logout')
        return
      }
      this.users = await resp.json()
    },
    async saveUser() {
      const payload = {
        username: this.form.username,
        password: this.form.password,
        role: this.form.role,
        contactName: this.form.contactName,
        phone: this.form.phone,
        email: this.form.email
      }
      const isEditing = this.isEditing
      const url = isEditing ? `/api/admin/users/${this.form.id}` : '/api/admin/users'
      const method = isEditing ? 'PUT' : 'POST'
      const resp = await fetch(url, {
        method,
        credentials: 'include',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': this.getCSRF()
        },
        body: JSON.stringify(payload)
      })
      if (!resp.ok) {
        const msg = await this.readError(resp)
        alert(msg)
        if (resp.status === 401) this.$emit('logout')
        return
      }
      await this.loadUsers()
      this.resetForm()
    },
    async deleteUser(user) {
      if (!confirm(`确认删除用户 ${user.username} ?`)) return
      const resp = await fetch(`/api/admin/users/${user.id}`, {
        method: 'DELETE',
        credentials: 'include',
        headers: { 'X-CSRF-Token': this.getCSRF() }
      })
      if (!resp.ok) {
        const msg = await this.readError(resp)
        alert(msg)
        if (resp.status === 401) this.$emit('logout')
        return
      }
      await this.loadUsers()
    },
    async loadPrintRecords() {
      const params = new URLSearchParams()
      if (this.printFilters.username) params.set('username', this.printFilters.username)
      if (this.printFilters.start) params.set('start', this.printFilters.start)
      if (this.printFilters.end) params.set('end', this.printFilters.end)
      const resp = await fetch(`/api/admin/print-records?${params.toString()}`, { credentials: 'include' })
      if (!resp.ok) {
        if (resp.status === 401) this.$emit('logout')
        return
      }
      this.printRecords = await resp.json()
    },
    async loadSettings() {
      const resp = await fetch('/api/admin/settings', { credentials: 'include' })
      if (!resp.ok) {
        if (resp.status === 401) this.$emit('logout')
        return
      }
      const data = await resp.json()
      this.settings.retentionDays = String(data.retentionDays || 0)
    },
    async saveSettings() {
      const payload = {
        retentionDays: parseInt(this.settings.retentionDays || '0', 10)
      }
      const resp = await fetch('/api/admin/settings', {
        method: 'PUT',
        credentials: 'include',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': this.getCSRF()
        },
        body: JSON.stringify(payload)
      })
      if (!resp.ok) {
        const msg = await this.readError(resp)
        alert(msg)
        if (resp.status === 401) this.$emit('logout')
        return
      }
      await this.loadSettings()
    }
  }
}
</script>