import { Slot } from '@radix-ui/react-slot'
import { cva, type VariantProps } from 'class-variance-authority'
import type { ButtonHTMLAttributes } from 'react'
import { cn } from '@/lib/utils'

const buttonVariants = cva(
  'inline-flex items-center justify-center gap-2 whitespace-nowrap rounded-2xl text-sm font-semibold transition-all duration-200 outline-none focus-visible:ring-2 focus-visible:ring-emerald-500 disabled:pointer-events-none disabled:opacity-50 active:scale-[.98]',
  {
    variants: {
      variant: {
        default: 'bg-emerald-800 text-white shadow-sm hover:bg-emerald-900 dark:bg-emerald-500 dark:text-emerald-950 dark:hover:bg-emerald-400',
        secondary: 'bg-stone-100 text-stone-800 hover:bg-stone-200 dark:bg-white/10 dark:text-stone-100 dark:hover:bg-white/15',
        ghost: 'text-stone-600 hover:bg-stone-100 hover:text-stone-950 dark:text-stone-300 dark:hover:bg-white/10 dark:hover:text-white',
        outline: 'border border-stone-200 bg-white/80 text-stone-800 hover:border-emerald-700 dark:border-white/15 dark:bg-white/5 dark:text-stone-100',
      },
      size: {
        default: 'h-11 px-5',
        sm: 'h-9 rounded-xl px-3',
        icon: 'size-11 p-0',
      },
    },
    defaultVariants: { variant: 'default', size: 'default' },
  },
)

type ButtonProps = ButtonHTMLAttributes<HTMLButtonElement> &
  VariantProps<typeof buttonVariants> & { asChild?: boolean }

export function Button({ className, variant, size, asChild, ...props }: ButtonProps) {
  const Comp = asChild ? Slot : 'button'
  return <Comp className={cn(buttonVariants({ variant, size, className }))} {...props} />
}
