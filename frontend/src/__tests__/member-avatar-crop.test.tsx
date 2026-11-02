/** @jest-environment jsdom */
import { fireEvent, render, screen, waitFor } from "@testing-library/react";
import { MemberAvatar } from "@/components/site/member-avatar";
import { ProfilePhotoCropper } from "@/components/site/profile-photo-cropper";

test("saved photo replaces initials, changes on replacement, and removal/errors restore initials", () => {
  const member = { user_id: "ada", display_name: "Ada", avatar_url: "https://storage.test/first.png" };
  const view = render(<MemberAvatar member={member} />);
  expect(screen.getByAltText("").getAttribute("src")).toBe(member.avatar_url);
  fireEvent.error(screen.getByAltText(""));
  expect(screen.queryByAltText("")).toBeNull();
  expect(screen.getByText("A")).toBeTruthy();
  view.rerender(<MemberAvatar member={{ ...member, avatar_url: "https://storage.test/replaced.png" }} />);
  expect(screen.getByAltText("").getAttribute("src")).toContain("replaced.png");
  view.rerender(<MemberAvatar member={{ ...member, avatar_url: "" }} />);
  expect(screen.queryByAltText("")).toBeNull();
  view.rerender(<MemberAvatar member={{ ...member, avatar_url: "javascript:invalid" }} />);
  expect(screen.queryByAltText("")).toBeNull();
});

describe("profile adjustment", () => {
  const draw = jest.fn(), revoke = jest.fn();
  beforeEach(() => {
    jest.clearAllMocks();
    URL.createObjectURL = jest.fn(() => "blob:fixture"); URL.revokeObjectURL = revoke;
    jest.spyOn(window, "Image").mockImplementation(() => {
      const image = document.createElement("img");
      Object.defineProperties(image, { naturalWidth: { value: 800 }, naturalHeight: { value: 400 }, src: { set: () => queueMicrotask(() => image.onload?.(new Event("load"))) } });
      return image;
    });
    jest.spyOn(HTMLCanvasElement.prototype, "getContext").mockReturnValue({ drawImage: draw } as unknown as CanvasRenderingContext2D);
    jest.spyOn(HTMLCanvasElement.prototype, "toBlob").mockImplementation(callback => callback(new Blob(["cropped"], { type: "image/png" })));
  });
  afterEach(() => jest.restoreAllMocks());
  const file = () => new File(["image"], "original.jpg", { type: "image/jpeg" });
  test("zoomed preview and exported square use the same pixels; nothing saves before consent", async () => {
    const save = jest.fn().mockResolvedValue(undefined);
    const view = render(<ProfilePhotoCropper file={file()} onCancel={jest.fn()} onSave={save} />);
    await waitFor(() => expect((screen.getByText("Use photo") as HTMLButtonElement).disabled).toBe(false));
    expect(save).not.toHaveBeenCalled();
    fireEvent.change(screen.getByLabelText("Photo zoom"), { target: { value: "2" } });
    expect(draw.mock.calls.at(-1)?.slice(1)).toEqual([300, 100, 200, 200, 0, 0, 512, 512]);
    fireEvent.click(screen.getByText("Use photo"));
    await waitFor(() => expect(save).toHaveBeenCalledTimes(1));
    const output = save.mock.calls[0][0] as File;
    expect(output.name).toBe("avatar.png"); expect(output.type).toBe("image/png");
    expect(draw.mock.calls.at(-1)?.slice(1)).toEqual([300, 100, 200, 200, 0, 0, 512, 512]);
    view.unmount(); expect(revoke).toHaveBeenCalledWith("blob:fixture");
  });
  test("cancel performs no save, while a failed upload keeps the adjusted photo available to retry", async () => {
    const save = jest.fn().mockRejectedValueOnce(new Error("offline")).mockResolvedValue(undefined), cancel = jest.fn();
    render(<ProfilePhotoCropper file={file()} onCancel={cancel} onSave={save} />);
    await waitFor(() => expect((screen.getByText("Use photo") as HTMLButtonElement).disabled).toBe(false));
    fireEvent.click(screen.getByText("Use photo"));
    await screen.findByRole("alert");
    expect((screen.getByText("Use photo") as HTMLButtonElement).disabled).toBe(false);
    fireEvent.click(screen.getByText("Cancel")); expect(cancel).toHaveBeenCalledTimes(1);
    expect(save).toHaveBeenCalledTimes(1);
  });
  test("dragging and two-pointer zoom change the crop used for export", async () => {
    const original = window.PointerEvent;
    window.PointerEvent = class extends MouseEvent {
      pointerId: number;
      constructor(type: string, init: PointerEventInit = {}) { super(type, init); this.pointerId = init.pointerId || 0; }
    } as typeof PointerEvent;
    const save = jest.fn().mockResolvedValue(undefined);
    try {
      render(<ProfilePhotoCropper file={file()} onCancel={jest.fn()} onSave={save} />);
      await waitFor(() => expect((screen.getByText("Use photo") as HTMLButtonElement).disabled).toBe(false));
      const preview = screen.getByLabelText("Profile photo preview") as HTMLCanvasElement;
      preview.setPointerCapture = jest.fn();
      preview.getBoundingClientRect = () => ({ left: 0, top: 0, width: 320, height: 320 } as DOMRect);
      fireEvent.pointerDown(preview, { pointerId: 1, clientX: 160, clientY: 160 });
      fireEvent.pointerMove(preview, { pointerId: 1, clientX: 80, clientY: 160 });
      expect(draw.mock.calls.at(-1)?.slice(1, 5)).toEqual([300, 0, 400, 400]);
      fireEvent.pointerDown(preview, { pointerId: 2, clientX: 240, clientY: 160 });
      fireEvent.pointerMove(preview, { pointerId: 1, clientX: 40, clientY: 160 });
      fireEvent.pointerMove(preview, { pointerId: 2, clientX: 280, clientY: 160 });
      expect(Number((screen.getByLabelText("Photo zoom") as HTMLInputElement).value)).toBeGreaterThan(1);
      const source = draw.mock.calls.at(-1)?.slice(1, 5);
      fireEvent.click(screen.getByText("Use photo"));
      await waitFor(() => expect(save).toHaveBeenCalledTimes(1));
      expect(draw.mock.calls.at(-1)?.slice(1, 5)).toEqual(source);
    } finally { window.PointerEvent = original; }
  });
});
