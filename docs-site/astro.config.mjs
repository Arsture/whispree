import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';

export default defineConfig({
  site: 'https://docs-site-azure-psi.vercel.app',
  integrations: [
    starlight({
      title: 'Whispree Docs',
      description: 'Fast voice-to-prompt documentation for Whispree.',
      customCss: ['./src/styles/custom.css'],
      favicon: '/favicon.svg',
      social: [
        {
          icon: 'github',
          label: 'GitHub',
          href: 'https://github.com/Arsture/whispree'
        }
      ],
      sidebar: [
        {
          label: 'Start',
          items: [
            { label: 'Overview', slug: '' },
            { label: 'Getting started', slug: 'getting-started' }
          ]
        },
        {
          label: 'Concepts',
          items: [
            { label: 'Architecture', slug: 'concepts/architecture' }
          ]
        },
        {
          label: 'Guides',
          items: [
            { label: 'Providers', slug: 'guides/providers' },
            { label: 'Permissions', slug: 'guides/permissions' }
          ]
        },
        {
          label: 'Reference',
          items: [
            { label: 'Release process', slug: 'reference/release-process' },
            { label: 'Feature doc template', slug: 'reference/feature-doc-template' }
          ]
        }
      ]
    })
  ]
});
