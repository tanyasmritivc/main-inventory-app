"use client";

import { useState } from "react";
import { chunkFades, useAnswerPresentation } from "./ask-stream-presentation";
import Markdown, { defaultUrlTransform } from "react-markdown";
import remarkGfm from "remark-gfm";

function answerUrl(value: string) {
  const safe = defaultUrlTransform(value);
  return /^(https?:\/\/|mailto:|\/(?!\/)|#)/i.test(safe) ? safe : "";
}

export function AskMarkdown({ children, animate = false }: { children: string; animate?: boolean }) {
  const shown = useAnswerPresentation(children, animate);
  const [fadePlugin] = useState(() => chunkFades({ text: "", times: [] }));
  const partial = animate && (shown.match(/\*\*/g)?.length ?? 0) % 2 ? `${shown}**` : shown;
  return (
    <div className="ask-body ask-markdown">
      <Markdown
        skipHtml
        remarkPlugins={[remarkGfm]}
        rehypePlugins={animate ? [fadePlugin] : []}
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
        {partial}
      </Markdown>
    </div>
  );
}
