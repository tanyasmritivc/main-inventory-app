"use client";

import { FormEvent, useCallback, useEffect, useRef, useState } from "react";
import { Bot, MessageSquarePlus, Send, Trash2 } from "lucide-react";
import { ConversationMessage, ConversationSummary, deleteConversation, getConversation, getConversations, streamAiCommand } from "@/lib/api";
import { useApiSession } from "@/lib/use-api-session";

export function AssistClient() {
  const { token } = useApiSession();
  const [conversations, setConversations] = useState<ConversationSummary[]>([]);
  const [conversationId, setConversationId] = useState<string | null>(null);
  const [messages, setMessages] = useState<ConversationMessage[]>([]);
  const [input, setInput] = useState("");
  const [sending, setSending] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const endRef = useRef<HTMLDivElement>(null);

  const loadConversations = useCallback(async () => {
    if (!token) return [];
    const list = await getConversations({ token }); setConversations(list); return list;
  }, [token]);

  useEffect(() => { if (token) void loadConversations().catch(() => setError("Could not load chat history.")); }, [loadConversations, token]);
  useEffect(() => { endRef.current?.scrollIntoView({ behavior: "smooth" }); }, [messages]);
  useEffect(() => { const draft = window.localStorage.getItem("findez-assist-draft"); if (draft) setInput(draft); }, []);
  useEffect(() => { window.localStorage.setItem("findez-assist-draft", input); }, [input]);

  async function openConversation(id: string) {
    if (!token) return;
    setConversationId(id); setError(null);
    try { const result = await getConversation({ token, conversationId: id }); setMessages(result.messages ?? []); }
    catch { setError("Could not open that conversation."); }
  }

  function newChat() { setConversationId(null); setMessages([]); setError(null); setInput(""); }

  async function removeConversation(event: React.MouseEvent, id: string) {
    event.stopPropagation(); if (!token || !window.confirm("Delete this conversation?")) return;
    await deleteConversation({ token, conversationId: id });
    if (conversationId === id) newChat(); await loadConversations();
  }

  async function send(event: FormEvent) {
    event.preventDefault();
    const text = input.trim(); if (!token || !text || sending) return;
    setSending(true); setError(null); setInput(""); window.localStorage.removeItem("findez-assist-draft");
    const userMessage: ConversationMessage = { id: `user-${Date.now()}`, role: "user", content: text, created_at: new Date().toISOString() };
    const assistantId = `assistant-${Date.now()}`;
    setMessages((current) => [...current, userMessage, { id: assistantId, role: "assistant", content: "", created_at: new Date().toISOString() }]);
    try {
      await streamAiCommand({ token, message: text, conversationId, onDelta: (delta) => setMessages((current) => current.map((message) => message.id === assistantId ? { ...message, content: message.content + delta } : message)) });
      const list = await loadConversations();
      if (!conversationId && list[0]) setConversationId(list[0].id);
    } catch (reason) {
      setMessages((current) => current.filter((message) => message.id !== assistantId));
      setError(reason instanceof Error ? reason.message : "Assist could not complete that request.");
    } finally { setSending(false); }
  }

  return (
    <section className="assist-layout">
      <aside className="assist-history product-card">
        <div className="assist-history-header"><span>Conversations</span><button className="app-icon-button" onClick={newChat} aria-label="New conversation"><MessageSquarePlus size={17} /></button></div>
        <div className="assist-history-list">
          {conversations.map((conversation) => <button className={conversation.id === conversationId ? "is-active" : ""} key={conversation.id} onClick={() => void openConversation(conversation.id)}><span>{conversation.title || "New chat"}</span><Trash2 size={13} onClick={(event) => void removeConversation(event, conversation.id)} /></button>)}
          {conversations.length === 0 && <p>Your conversation history will appear here.</p>}
        </div>
      </aside>
      <div className="assist-chat product-card">
        <header><div><Bot size={20} /><span>FindEZ Assist</span></div><button className="product-button" onClick={newChat}><MessageSquarePlus size={14} />New chat</button></header>
        <div className="assist-messages">
          {messages.length === 0 && <div className="assist-welcome"><Bot size={28} /><h1>Work through your inventory.</h1><p>Ask where something is, update quantities, plan a project, or summarize what needs attention.</p><div>{["What is running low?", "Find 1/4-inch fasteners", "What changed this week?"].map((prompt) => <button key={prompt} onClick={() => setInput(prompt)}>{prompt}</button>)}</div></div>}
          {messages.map((message) => <article className={`assist-message ${message.role}`} key={message.id}><span>{message.role === "assistant" ? "FindEZ" : "You"}</span><div>{message.content || (sending ? "Thinking…" : "")}</div></article>)}
          <div ref={endRef} />
        </div>
        {error && <div className="notice-error assist-error">{error}</div>}
        <form className="assist-composer" onSubmit={(event) => void send(event)}><textarea value={input} onChange={(event) => setInput(event.target.value)} onKeyDown={(event) => { if (event.key === "Enter" && !event.shiftKey) { event.preventDefault(); event.currentTarget.form?.requestSubmit(); } }} placeholder="Ask FindEZ about your inventory…" maxLength={4000} /><button disabled={!input.trim() || sending} aria-label="Send"><Send size={17} /></button></form>
      </div>
    </section>
  );
}
