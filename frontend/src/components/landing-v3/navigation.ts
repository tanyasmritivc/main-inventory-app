import { previewPrompt } from '@/lib/landing-preview';
export function signupUrl(prompt: string) {
  const text = previewPrompt(prompt);
  return text ? `/signup?prompt=${encodeURIComponent(text)}` : '/signup';
}
