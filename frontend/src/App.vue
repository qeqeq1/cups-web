<template>
  <UApp>
    <div class="grid grid-rows-[auto_1fr_auto] min-h-screen w-full bg-default">
      <header class="flex items-center justify-between px-6 py-3 border-b border-default bg-default">
        <div class="flex items-center gap-3">
          <h1 class="text-xl font-bold">CUPS 打印</h1>
          <span v-if="session" class="text-sm text-muted">{{ session.username }}</span>
        </div>
        <div class="flex items-center gap-2">
          <UButton v-if="isAdmin" :variant="$route.path === '/print' ? 'solid' : 'ghost'" size="sm" @click="$router.push('/print')">打印</UButton>
          <UButton v-if="isAdmin" :variant="$route.path === '/admin' ? 'solid' : 'ghost'" size="sm" @click="$router.push('/admin')">管理</UButton>
          <UButton v-if="session" variant="outline" size="sm" @click="logout">登出</UButton>
        </div>
      </header>
      <div class="overflow-auto relative">
        <router-view :session="session" @login-success="onLogin" @logout="onLogout" />
      </div>
      <footer class="px-6 py-3 border-t border-default bg-default text-sm text-muted text-center">
        Powered by <a href="https://github.com/hanxi/cups-web" target="_blank" class="text-primary hover:underline">cups-web</a>
      </footer>
    </div>
  </UApp>
</template>

<script>
import LoginView from './views/LoginView.vue'
import PrintView from './views/PrintView.vue'
import AdminView from './views/AdminView.vue'

export default {
  data() {
    return { session: null }
  },
  async mounted() {
    await this.loadSession()
  },
  components: { LoginView, PrintView, AdminView },
  computed: {
    isAdmin() {
      return this.session && this.session.role === 'admin'
    }
  },
  methods: {
    async loadSession() {
      try {
        const resp = await fetch('/api/session', { credentials: 'include' })
        if (resp.ok) {
          this.session = await resp.json()
          this.$router.push('/print')
        } else {
          this.session = null
          this.$router.push('/login')
        }
      } catch (e) {
        this.session = null
      }
    },
    async onLogin() {
      await this.loadSession()
    },
    onLogout() {
      this.session = null
      this.$router.push('/login')
    },
    async logout() {
      try {
        await fetch('/api/logout', { method: 'POST', credentials: 'include' })
      } catch (e) {
        // ignore errors
      }
      this.onLogout()
    }
  }
}
</script>
