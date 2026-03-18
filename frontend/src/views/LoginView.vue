<template>
  <div class="flex items-center justify-center h-full p-6">
    <UCard class="w-full max-w-md shadow-lg">
      <template #header>
        <h2 class="text-xl font-bold flex items-center gap-2">
          <UIcon name="i-lucide-user" class="w-5 h-5" />
          登录
        </h2>
      </template>
      
      <!-- 错误提示 -->
      <UAlert
        v-if="error"
        icon="i-lucide-triangle-alert"
        color="error"
        variant="soft"
        class="mb-6"
      >
        {{ error }}
      </UAlert>
      
      <UForm @submit="login" :state="state" class="space-y-6">
        <UFormField label="用户名" name="username" required>
          <UInput v-model="state.username" icon="i-lucide-user" size="lg" class="w-full" />
        </UFormField>
        <UFormField label="密码" name="password" required>
          <UInput v-model="state.password" type="password" icon="i-lucide-lock" size="lg" class="w-full" />
        </UFormField>
        
        <div class="mt-6">
          <UButton 
            type="submit" 
            color="primary" 
            icon="i-lucide-log-in" 
            size="lg"
            class="w-full"
            :loading="loading"
          >
            登录
          </UButton>
        </div>
      </UForm>
    </UCard>
  </div>
</template>

<script setup>
import { reactive, ref } from 'vue'

const state = reactive({
  username: '',
  password: ''
})
const error = ref('')
const loading = ref(false)

const emit = defineEmits(['login-success'])

async function login() {
  error.value = ''
  loading.value = true
  try {
    const resp = await fetch('/api/login', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ username: state.username, password: state.password }),
      credentials: 'include'
    })
    if (!resp.ok) {
      error.value = '登录失败'
      return
    }
    emit('login-success')
  } catch (e) {
    error.value = e.message
  } finally {
    loading.value = false
  }
}
</script>
