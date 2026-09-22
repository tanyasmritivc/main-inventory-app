import type { SVGProps } from "react";

export function FindEZMark({ className, ...props }: SVGProps<SVGSVGElement>) {
  return (
    <svg className={className} viewBox="0 0 96 96" fill="none" aria-hidden="true" {...props}>
      <path d="M25.25 40.75H55.25V70.75" stroke="currentColor" strokeWidth="11" strokeLinejoin="miter" />
      <path d="M50.25 30.75H65.25V45.75" stroke="#E8590C" strokeWidth="11" strokeLinejoin="miter" />
    </svg>
  );
}
