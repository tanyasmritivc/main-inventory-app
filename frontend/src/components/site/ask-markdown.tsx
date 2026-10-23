"use client";

import Markdown, { defaultUrlTransform } from "react-markdown";
import remarkGfm from "remark-gfm";

function answerUrl(value: string) {
  const safe = defaultUrlTransform(value);
  return /^(https?:\/\/|mailto:|\/(?!\/)|#)/i.test(safe) ? safe : "";
}

export function AskMarkdown({ children }: { children: string }) {
  return (
    <div className="ask-body ask-markdown">
      <Markdown
        skipHtml
        remarkPlugins={[remarkGfm]}
        urlTransform={answerUrl}
        disallowedElements={["img", "iframe", "script", "style", "form", "input", "button"]}
        components={{
          a: ({ href, children }) => href ? (
            <a href={href} target={/^https?:/i.test(href) ? "_blank" : undefined} rel="noopener noreferrer nofollow">
              {children}
            </a>
          ) : <span>{children}</span>,
          table: ({ children }) => <div className="ask-markdown-table"><table>{children}</table></div>,
          hr: () => null,
        }}
      >
        {children}
      </Markdown>
    </div>
  );
}
