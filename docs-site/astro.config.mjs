import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';

export default defineConfig({
  site: 'https://docs-site-azure-psi.vercel.app',
  integrations: [
    starlight({
      title: 'Whispree',
      description: 'Whispree 사용 설명서 — macOS 음성 받아쓰기 앱의 기능과 사용법. / How to use Whispree, the macOS voice dictation app.',
      customCss: ['./src/styles/custom.css'],
      favicon: '/whispree-icon.png',
      logo: { src: './src/assets/whispree-icon.png', replacesTitle: false },
      // 한국어(root) + English(/en) 이중언어
      defaultLocale: 'root',
      locales: {
        root: { label: '한국어', lang: 'ko' },
        en: { label: 'English', lang: 'en' }
      },
      social: [
        {
          icon: 'github',
          label: 'GitHub',
          href: 'https://github.com/Arsture/whispree'
        }
      ],
      sidebar: [
        {
          label: '시작하기',
          translations: { en: 'Start' },
          items: [
            { label: '개요', translations: { en: 'Overview' }, slug: '' },
            { label: '설치 & 첫 받아쓰기', translations: { en: 'Install & first dictation' }, slug: 'getting-started' }
          ]
        },
        {
          label: '기능',
          translations: { en: 'Features' },
          items: [
            { label: '받아쓰기 & 멀티 녹음', translations: { en: 'Dictation & multi-recording' }, slug: 'features/dictation' },
            { label: 'STT 엔진', translations: { en: 'STT engines' }, slug: 'features/stt' },
            { label: 'AI 교정', translations: { en: 'AI correction' }, slug: 'features/correction' },
            { label: '단어 사전 & Quick Fix', translations: { en: 'Dictionary & Quick Fix' }, slug: 'features/dictionary' },
            { label: '화면 컨텍스트 & 복원', translations: { en: 'Visual context & restore' }, slug: 'features/context' },
            { label: '모델 & 호환성', translations: { en: 'Models & compatibility' }, slug: 'features/models' }
          ]
        },
        {
          label: '참고',
          translations: { en: 'Reference' },
          items: [
            { label: '권한', translations: { en: 'Permissions' }, slug: 'reference/permissions' },
            { label: '단축키', translations: { en: 'Shortcuts' }, slug: 'reference/shortcuts' },
            { label: '구조 한눈에', translations: { en: 'Architecture at a glance' }, slug: 'reference/architecture' }
          ]
        }
      ]
    })
  ]
});
