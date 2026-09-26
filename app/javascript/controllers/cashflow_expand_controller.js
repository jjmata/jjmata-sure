import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  open() {
    const dialog = this.element.querySelector("dialog");
    if (!dialog) return;

    // A dialog restored from a Turbo snapshot keeps its `open` attribute but
    // is no longer modal, and showModal() throws InvalidStateError on it.
    if (dialog.matches(":modal")) return;
    if (dialog.open) dialog.close();

    if (typeof this.originalDraggable === "undefined") {
      this.originalDraggable = this.element.getAttribute("draggable");
    }
    this.element.setAttribute("draggable", "false");

    dialog.showModal();
  }

  restore() {
    if (this.originalDraggable === undefined) return;
    if (this.element.querySelector("dialog")?.open) return;
    this.originalDraggable
      ? this.element.setAttribute("draggable", this.originalDraggable)
      : this.element.removeAttribute("draggable");
    this.originalDraggable = undefined;
  }

  closeBeforeCache() {
    const dialog = this.element.querySelector("dialog");
    if (!dialog?.open) return;

    // Restore now, because the close event fires after Turbo takes the snapshot.
    dialog.close();
    this.restore();
  }
}
