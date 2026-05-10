import * as React from "react"

import { cn } from "@/lib/utils"

function Textarea({ className, ...props }: React.ComponentProps<"textarea">) {
  return (
    <textarea
      data-slot="textarea"
      className={cn(
        "placeholder:text-white/20 text-white bg-white/[0.04] border border-white/[0.10] flex field-sizing-content min-h-16 w-full rounded-[12px] px-3 py-2 text-base outline-none transition-all duration-200 hover:border-white/[0.20] focus-visible:border-white/30 focus-visible:ring-0 focus-visible:shadow-[0_0_0_3px_rgba(255,255,255,0.05)] aria-invalid:border-destructive disabled:cursor-not-allowed disabled:opacity-50 md:text-sm",
        className
      )}
      {...props}
    />
  )
}

export { Textarea }
