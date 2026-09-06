import path from 'node:path'
import { fileURLToPath } from 'node:url'
import { postgresAdapter } from '@payloadcms/db-postgres'
import { lexicalEditor } from '@payloadcms/richtext-lexical'
import { s3Storage } from '@payloadcms/storage-s3'
import { buildConfig } from 'payload'
import sharp from 'sharp'
import { Admins } from './collections/Admins'
import { Books } from './collections/Books'
import { Categories } from './collections/Categories'
import { Media } from './collections/Media'

const filename = fileURLToPath(import.meta.url)
const dirname = path.dirname(filename)
const useR2 = Boolean(process.env.S3_BUCKET && process.env.S3_ACCESS_KEY_ID && process.env.S3_SECRET_ACCESS_KEY)

export default buildConfig({
  serverURL: process.env.NEXT_PUBLIC_SERVER_URL,
  secret: process.env.PAYLOAD_SECRET || '',
  admin: {
    user: Admins.slug,
    meta: { titleSuffix: '— މަކްތަބާ އިދާރާ' },
    components: {
      graphics: { Logo: './src/components/Logo#Logo', Icon: './src/components/Logo#Icon' },
      beforeDashboard: ['./src/components/Welcome#Welcome'],
    },
  },
  i18n: {
    fallbackLanguage: 'en',
    translations: {
      en: {
        authentication: {
          backToLogin: 'ލޮގިން ޞަފްޙާއަށް',
          beginCreateFirstUser: 'ފެށުމަށް ފުރަތަމަ އެޑްމިން އަކައުންޓް ހަދައްވާ.',
          confirmPassword: 'ޕާސްވޯޑު ޔަޤީންކުރައްވާ',
          createFirstUser: 'ފުރަތަމަ އެޑްމިން ހަދައްވާ',
          emailOrUsername: 'އީމެއިލް',
          forgotPasswordQuestion: 'ޕާސްވޯޑު ހަނދާންނެތުނީތޯ؟',
          logOut: 'ލޮގްއައުޓް',
          login: 'ލޮގިން',
          newPassword: 'އާ ޕާސްވޯޑު',
        },
        general: {
          cancel: 'ކެންސަލް',
          create: 'ހަދައްވާ',
          email: 'އީމެއިލް',
          save: 'ސޭވްކުރައްވާ',
          search: 'ހޯއްދަވާ',
          welcome: 'މަރުޙަބާ',
        },
      },
    },
  },
  localization: {
    locales: [{ code: 'dv', label: 'ދިވެހި', rtl: true }],
    defaultLocale: 'dv',
    fallback: true,
  },
  collections: [Admins, Categories, Books, Media],
  db: postgresAdapter({ pool: { connectionString: process.env.DATABASE_URI } }),
  editor: lexicalEditor(),
  sharp,
  typescript: { outputFile: path.resolve(dirname, 'payload-types.ts') },
  plugins: [
    s3Storage({
      enabled: useR2,
      collections: { media: { prefix: 'library' } },
      bucket: process.env.S3_BUCKET || '',
      clientUploads: true,
      config: {
        credentials: {
          accessKeyId: process.env.S3_ACCESS_KEY_ID || '',
          secretAccessKey: process.env.S3_SECRET_ACCESS_KEY || '',
        },
        endpoint: process.env.S3_ENDPOINT,
        region: process.env.S3_REGION || 'auto',
      },
    }),
  ],
})
