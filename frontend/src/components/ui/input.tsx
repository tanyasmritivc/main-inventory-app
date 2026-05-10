import * as React from "react"

import { cn } from "@/lib/utils"

function Input({ className, type, ...props }: React.ComponentProps<"input">) {
  return (
    <input
      type={type}
      data-slot="input"
      className={cn(
        "file:text-foreground placeholder:text-white/20 text-white bg-white/[0.04] border border-white/[0.10] h-9 w-full min-w-0 rounded-[12px] px-3 py-1 text-base transition-all duration-200 outline-none hover:border-white/[0.20] disabled:pointer-events-none disabled:cursor-not-allowed disabled:opacity-50 md:text-sm",
        "focus-visible:border-white/30 focus-visible:ring-0 focus-visible:shadow-[0_0_0_3px_rgba(255,255,255,0.05)]",
        "aria-invalid:border-destructive",
        className
      )}
      {...props}
    />
  )
}

export { Input }
