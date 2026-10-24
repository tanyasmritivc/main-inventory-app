import type { FormEvent } from 'react';
export function signupUrl(prompt: string) {
  const text = prompt.trim();
  return text ? `/signup?prompt=${encodeURIComponent(text)}` : '/signup';
}
export function submitPrompt(event: FormEvent<HTMLFormElement>, navigate: (url: string) => void) {
  event.preventDefault();
  const prompt = String(new FormData(event.currentTarget).get('prompt') ?? '');
  navigate(signupUrl(prompt));
}
