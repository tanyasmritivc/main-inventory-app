import type { Room, WorldItem } from './types';
import { placeLine } from './layout';

export type Question = { item: WorldItem; answer: string; options: string[] };
export function shuffled<T>(values: T[], random = Math.random): T[] {
  const result = [...values];
  for (let i = result.length - 1; i > 0; i--) { const j = Math.floor(random() * (i + 1)); [result[i], result[j]] = [result[j], result[i]]; }
  return result;
}
export function quizQuestions(room: Room | null, game: 'count' | 'where'): Question[] {
  const items = room && !room.sample && !room.public ? room.items.filter(item => !item.space_id || item.space_id === room.id) : [];
  const places = [...new Set(items.map(placeLine).filter(Boolean))];
  return shuffled(items.filter(i => game === 'count' ? Number.isFinite(i.quantity) : !!placeLine(i) && places.length > 1)).slice(0, 5).map(item => {
    const answer = game === 'count' ? String(item.quantity) : placeLine(item);
    const alternatives = game === 'where' ? shuffled(places.filter(p => p !== answer)).slice(0, 3)
      : [...new Set([Math.max(0, item.quantity! - 1), item.quantity! + 1, item.quantity! + 3, item.quantity! + 5])].filter(n => n !== item.quantity).slice(0, 3).map(String);
    return { item, answer, options: shuffled([answer, ...alternatives]) };
  });
}
