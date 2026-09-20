import type { SVGProps } from "react";

export function FindEZMark({ className, ...props }: SVGProps<SVGSVGElement>) {
  return (
    <svg className={className} viewBox="0 0 96 96" fill="none" aria-hidden="true" {...props}>
      <path d="M28 38H58V68" stroke="currentColor" strokeWidth="11" strokeLinejoin="miter" />
      <path d="M53 28H68V43" stroke="#E8590C" strokeWidth="11" strokeLinejoin="miter" />
    </svg>
  );
}
