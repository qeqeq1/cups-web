<template>
  <div class="p-6">
    <UCard>
      <template #header>
        <h2 class="text-xl font-bold flex items-center gap-2">
          <UIcon name="i-lucide-printer" class="w-5 h-5" />
          打印
        </h2>
      </template>

      <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
        <div class="col-span-1 space-y-4">
          <UFormField label="打印机">
            <USelect
              v-model="printer"
              :items="printerItems"
              value-key="value"
              label-key="label"
              class="w-full"
            />
          </UFormField>

          <UFormField label="文件">
            <input type="file" ref="file" @change="onFileChange" class="file-input file-input-bordered w-full" />
          </UFormField>

          <UFormField label="打印选项">
            <USelect
              v-model="isDuplex"
              :items="duplexItems"
              value-key="value"
              label-key="label"
              class="w-full"
            />
          </UFormField>

          <UFormField label="颜色模式">
            <USelect
              v-model="isColor"
              :items="colorItems"
              value-key="value"
              label-key="label"
              class="w-full"
            />
          </UFormField>

          <div class="flex gap-2">
            <UButton color="primary" :disabled="!canPrint || converting" @click="uploadAndPrint" icon="i-lucide-printer">打印</UButton>
            <UButton :disabled="!canConvert" @click="convertToPdf" icon="i-lucide-file-text">转换</UButton>
            <UButton v-if="previewUrl" variant="ghost" :href="previewUrl" :download="downloadName" icon="i-lucide-download">下载预览</UButton>
          </div>

          <div class="text-sm text-muted">{{ msg }}</div>

          <div class="mt-4">
            <UAlert v-if="converting" color="info" variant="subtle" title="转换中…" />
            <UAlert v-if="converted" color="success" variant="subtle" title="已转换为 PDF" />
          </div>
        </div>

        <div class="col-span-2">
          <label class="label"><span class="label-text">预览</span></label>
          <div class="preview-container p-2 border rounded">
            <div v-if="previewType === 'image'" class="flex items-center justify-center">
              <img :src="previewUrl" alt="preview" class="max-h-[600px] max-w-full" />
            </div>
            <div v-else-if="previewType === 'pdf'">
              <iframe :src="previewUrl" style="width:100%; height:600px;" frameborder="0"></iframe>
            </div>
            <div v-else-if="previewType === 'text'" class="p-4 whitespace-pre-wrap overflow-auto h-64">
              {{ textPreview }}
            </div>
            <div v-else class="p-4 text-muted">无预览可用</div>
          </div>
        </div>
      </div>
    </UCard>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { jsPDF } from 'jspdf'

const printer = ref('')
const printers = ref([])
const msg = ref('')
const selectedFile = ref(null)
const previewUrl = ref('')
const previewType = ref('')
const textPreview = ref('')
const converting = ref(false)
const converted = ref(false)
const pdfBlob = ref(null)
const downloadName = ref('')
const isDuplex = ref(false)
const isColor = ref(true)

const emit = defineEmits(['logout'])

const printerItems = computed(() =>
  printers.value.map(p => ({ label: `${p.name} — ${p.uri}`, value: p.uri }))
)

const duplexItems = [
  { label: '单面打印', value: false },
  { label: '双面打印（长边翻转）', value: true }
]

const colorItems = [
  { label: '彩色打印', value: true },
  { label: '黑白打印', value: false }
]

const canPrint = computed(() => {
  return !!printer.value && (!!pdfBlob.value || !!selectedFile.value)
})

const canConvert = computed(() => {
  return !!selectedFile.value && !converting.value && selectedFile.value.type !== 'application/pdf'
})

function getCSRF() {
  const m = document.cookie.match('(^|;)\\s*csrf_token\\s*=\\s*([^;]+)')
  return m ? m.pop() : ''
}

async function readError(resp) {
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
}

function clearPreview() {
  if (previewUrl.value) {
    try {
      URL.revokeObjectURL(previewUrl.value)
    } catch (e) {
      // ignore
    }
  }
  previewUrl.value = ''
  previewType.value = ''
  textPreview.value = ''
  pdfBlob.value = null
  converted.value = false
  selectedFile.value = null
  downloadName.value = ''
}

function isOfficeFile(f) {
  return /\.(docx?|pptx?|xlsx?)$/i.test(f.name) || [
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'application/msword',
    'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    'application/vnd.ms-powerpoint',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'application/vnd.ms-excel'
  ].includes(f.type)
}

async function imageFileToPdfBlob(file) {
  return new Promise((resolve, reject) => {
    const img = new Image()
    img.onload = () => {
      const canvas = document.createElement('canvas')
      canvas.width = img.width
      canvas.height = img.height
      const ctx = canvas.getContext('2d')
      ctx.drawImage(img, 0, 0)
      const imgData = canvas.toDataURL('image/jpeg', 1.0)
      const doc = new jsPDF({ unit: 'px', format: [img.width, img.height] })
      doc.addImage(imgData, 'JPEG', 0, 0, img.width, img.height)
      const blob = doc.output('blob')
      resolve(blob)
    }
    img.onerror = () => reject(new Error('Failed to load image for conversion'))
    img.src = URL.createObjectURL(file)
  })
}

function textToPdfBlob(text) {
  const doc = new jsPDF()
  const lines = doc.splitTextToSize(text || '', 180)
  doc.text(lines, 10, 10)
  return doc.output('blob')
}

async function convertOfficeToPdf(file) {
  const fd = new FormData()
  fd.append('file', file, file.name)
  try {
    const resp = await fetch('/api/convert', {
      method: 'POST',
      body: fd,
      credentials: 'include',
      headers: { 'X-CSRF-Token': getCSRF() }
    })
    if (!resp.ok) {
      const t = await resp.text()
      throw new Error('server conversion failed: ' + t)
    }
    const blob = await resp.blob()
    return blob
  } catch (e) {
    throw e
  }
}

function onFileChange(e) {
  const f = e.target.files[0]
  clearPreview()
  if (!f) return
  selectedFile.value = f
  downloadName.value = f.name.replace(/\.[^/.]+$/, '') + '.pdf'

  if (f.type === 'application/pdf') {
    previewUrl.value = URL.createObjectURL(f)
    previewType.value = 'pdf'
    pdfBlob.value = f
    converted.value = true
  } else if (f.type.startsWith('image/')) {
    previewUrl.value = URL.createObjectURL(f)
    previewType.value = 'image'
    pdfBlob.value = null
    converted.value = false
    estimatePrice()
  } else if (isOfficeFile(f)) {
    previewType.value = 'text'
    textPreview.value = 'Office 文档（无法预览）。点击"转换"生成 PDF。'
    pdfBlob.value = null
    converted.value = false
  } else if (f.type.startsWith('text/') || /\.(txt|md|html)$/i.test(f.name)) {
    const reader = new FileReader()
    reader.onload = () => {
      textPreview.value = reader.result
      previewType.value = 'text'
    }
    reader.readAsText(f)
    pdfBlob.value = null
    converted.value = false
  } else {
    const reader = new FileReader()
    reader.onload = () => {
      const text = typeof reader.result === 'string' ? reader.result : ''
      textPreview.value = text.slice(0, 10000) || 'No preview available'
      previewType.value = 'text'
    }
    reader.readAsText(f)
    pdfBlob.value = null
    converted.value = false
  }
  estimatePrice()
}

async function convertToPdf() {
  if (!selectedFile.value) { msg.value = 'No file selected'; return }
  converting.value = true
  msg.value = ''
  try {
    const f = selectedFile.value
    let blob = null

    if (isOfficeFile(f)) {
      blob = await convertOfficeToPdf(f)
    } else if (f.type.startsWith('image/')) {
      blob = await imageFileToPdfBlob(f)
    } else if (f.type.startsWith('text/') || /\.(txt|md|html)$/i.test(f.name)) {
      const text = await f.text()
      blob = textToPdfBlob(text)
    } else {
      try {
        const text = await f.text()
        blob = textToPdfBlob(text)
      } catch (e) {
        throw new Error('Unsupported file type for conversion')
      }
    }

    pdfBlob.value = blob
    previewUrl.value = URL.createObjectURL(blob)
    previewType.value = 'pdf'
    converted.value = true
    msg.value = '已准备好转换'
  } catch (e) {
    msg.value = '转换失败：' + e.message
  } finally {
    converting.value = false
  }
}

async function uploadAndPrint() {
  if (!printer.value) { msg.value = '请选择打印机'; return }
  let fileToSend = null
  let filename = ''
  if (pdfBlob.value) {
    fileToSend = pdfBlob.value
    filename = downloadName.value || (selectedFile.value && selectedFile.value.name.replace(/\.[^/.]+$/, '') + '.pdf') || 'document.pdf'
  } else if (selectedFile.value) {
    fileToSend = selectedFile.value
    filename = selectedFile.value.name
  } else {
    msg.value = '没有可打印的文件'
    return
  }

  const form = new FormData()
  form.append('file', fileToSend, filename)
  form.append('printer', printer.value)
  form.append('duplex', isDuplex.value ? 'true' : 'false')
  form.append('color', isColor.value ? 'true' : 'false')

  try {
    const resp = await fetch('/api/print', {
      method: 'POST',
      body: form,
      credentials: 'include',
      headers: { 'X-CSRF-Token': getCSRF() }
    })
    if (!resp.ok) {
      msg.value = await readError(resp)
      if (resp.status === 401) emit('logout')
      return
    }
    const j = await resp.json()
    msg.value = '任务已加入队列：' + (j.jobId || '')
    localStorage.setItem('last_printer', printer.value)
  } catch (e) {
    msg.value = e.message
  }
}

onMounted(async () => {
  try {
    const resp = await fetch('/api/printers', { credentials: 'include' })
    if (resp.ok) {
      printers.value = await resp.json()
      const last = localStorage.getItem('last_printer')
      if (last) printer.value = last
      else if (printers.value.length > 0) printer.value = printers.value[0].uri
    } else if (resp.status === 401) {
      emit('logout')
    } else {
      msg.value = '加载打印机失败'
    }
  } catch (e) {
    msg.value = '加载打印机失败：' + e.message
  }
})
</script>