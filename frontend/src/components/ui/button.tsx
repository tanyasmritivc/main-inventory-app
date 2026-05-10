import * as React from "react"
import { Slot } from "@radix-ui/react-slot"
import { cva, type VariantProps } from "class-variance-authority"

import { cn } from "@/lib/utils"

const buttonVariants = cva(
  "inline-flex items-center justify-center gap-2 whitespace-nowrap text-sm font-medium transition-[opacity,transform,background-color,border-color,color] duration-150 disabled:pointer-events-none disabled:opacity-50 [&_svg]:pointer-events-none [&_svg:not([class*='size-'])]:size-4 shrink-0 [&_svg]:shrink-0 outline-none focus-visible:ring-2 focus-visible:ring-white/15 aria-invalid:border-destructive",
  {
    variants: {
      variant: {
        default:
          "rounded-full bg-white text-black font-semibold hover:opacity-[0.88] hover:-translate-y-px active:translate-y-0",
        destructive:
          "rounded-full bg-[rgba(255,59,48,0.15)] border border-[rgba(255,59,48,0.30)] text-[#FF3B30] hover:bg-[rgba(255,59,48,0.25)] hover:-translate-y-px active:translate-y-0",
        outline:
          "rounded-full border border-white/[0.12] bg-white/[0.06] text-white hover:bg-white/[0.09] hover:-translate-y-px active:translate-y-0",
        secondary:
          "rounded-full bg-white/[0.06] border border-white/[0.12] text-white hover:bg-white/[0.09] hover:-translate-y-px active:translate-y-0",
        ghost:
          "rounded-full bg-transparent text-white/75 hover:bg-white/[0.07] hover:text-white hover:-translate-y-px active:translate-y-0",
        link: "text-white/60 underline-offset-4 hover:underline hover:text-white",
      },
      size: {
        default: "h-9 px-5 py-2 has-[>svg]:px-3",
        sm: "h-8 rounded-full gap-1.5 px-4 has-[>svg]:px-2.5",
        lg: "h-11 rounded-full px-7 has-[>svg]:px-5",
        icon: "size-9 rounded-full",
        "icon-sm": "size-8 rounded-full",
        "icon-lg": "size-10 rounded-full",
      },
    },
    defaultVariants: {
      variant: "default",
      size: "default",
    },
  }
)

function Button({
  className,
  variant = "default",
  size = "default",
  asChild = false,
  ...props
}: React.ComponentProps<"button"> &
  VariantProps<typeof buttonVariants> & {
    asChild?: boolean
  }) {
  const Comp = asChild ? Slot : "button"

  return (
    <Comp
      data-slot="button"
      data-variant={variant}
      data-size={size}
      className={cn(buttonVariants({ variant, size, className }))}
      {...props}
    />
  )
}

export { Button, buttonVariants }
