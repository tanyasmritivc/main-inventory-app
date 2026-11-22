/** @jest-environment jsdom */
import { act, fireEvent, render, screen } from "@testing-library/react";
import { FoundingAccessProvider } from "@/components/founding-access/founding-access";

beforeEach(() => { jest.useFakeTimers(); });
afterEach(() => { jest.useRealTimers(); });

test("starting a question leaves the welcome deferred for the rest of the page", () => {
  render(<FoundingAccessProvider accountId="typing" createdAt={null} pathname="/worlds/personal"><textarea aria-label="Question" /></FoundingAccessProvider>);
  const question = screen.getByRole("textbox");
  question.focus();
  fireEvent.input(question, { target: { value: "Where are my gears?" } });
  act(() => { jest.advanceTimersByTime(1000); });
  expect(screen.queryByRole("dialog")).toBeNull();
  expect(document.activeElement).toBe(question);
});

test("an idle first visit still shows the welcome", () => {
  render(<FoundingAccessProvider accountId="idle" createdAt={null} pathname="/worlds/personal"><main>Inventory</main></FoundingAccessProvider>);
  act(() => { jest.advanceTimersByTime(1000); });
  expect(screen.getByRole("dialog")).toBeTruthy();
});
