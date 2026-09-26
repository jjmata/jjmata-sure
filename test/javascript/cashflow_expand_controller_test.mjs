import { readFile } from "node:fs/promises"
import { describe, it } from "node:test"
import assert from "node:assert/strict"

// The controller imports "@hotwired/stimulus" through the importmap, which
// Node has no equivalent of, so the specifier is rewritten to a stub and the
// shipped controller is imported as written.
const SOURCE_URL = new URL(
  "../../app/javascript/controllers/cashflow_expand_controller.js",
  import.meta.url,
)
const STIMULUS_STUB = `data:text/javascript,${encodeURIComponent(
  "export class Controller {}",
)}`

const source = (await readFile(SOURCE_URL, "utf8")).replace(
  '"@hotwired/stimulus"',
  JSON.stringify(STIMULUS_STUB),
)

const { default: CashflowExpandController } = await import(
  `data:text/javascript;base64,${Buffer.from(source).toString("base64")}`
)

// Models the native <dialog> rules that matter here: showModal() throws on a
// dialog that is open but not modal, and the close event fires in a later task.
class FakeDialog {
  constructor({ open = false, modal = false } = {}) {
    this.open = open
    this.modal = modal
    this.closeListeners = []
  }

  matches(selector) {
    return selector === ":modal" && this.modal
  }

  showModal() {
    if (this.open && !this.modal) {
      const error = new Error("Dialog is already open")
      error.name = "InvalidStateError"
      throw error
    }
    this.open = true
    this.modal = true
  }

  close() {
    if (!this.open) return
    this.open = false
    this.modal = false
    setTimeout(() => this.closeListeners.forEach((listener) => listener()))
  }
}

class FakeSection {
  constructor(dialog) {
    this.dialog = dialog
    this.attributes = new Map([["draggable", "true"]])
  }

  querySelector(selector) {
    return selector === "dialog" ? this.dialog : null
  }

  getAttribute(name) {
    return this.attributes.has(name) ? this.attributes.get(name) : null
  }

  setAttribute(name, value) {
    this.attributes.set(name, value)
  }

  removeAttribute(name) {
    this.attributes.delete(name)
  }
}

function buildController(dialog) {
  const element = new FakeSection(dialog)
  const controller = new CashflowExpandController()
  controller.element = element
  dialog.closeListeners.push(() => controller.restore())
  return { controller, element }
}

const nextTask = () => new Promise((resolve) => setTimeout(resolve))

describe("cashflow expand controller", () => {
  it("opens a closed dialog as a modal", () => {
    const dialog = new FakeDialog()
    const { controller, element } = buildController(dialog)

    controller.open()

    assert.equal(dialog.modal, true)
    assert.equal(element.getAttribute("draggable"), "false")
  })

  it("reopens a dialog restored open but not modal from a Turbo snapshot", async () => {
    const dialog = new FakeDialog({ open: true, modal: false })
    const { controller, element } = buildController(dialog)

    assert.doesNotThrow(() => controller.open())
    assert.equal(dialog.modal, true)

    // The close event from the reset must not restore dragging while the
    // modal is still open.
    await nextTask()
    assert.equal(element.getAttribute("draggable"), "false")
  })

  it("does nothing when the dialog is already modal", () => {
    const dialog = new FakeDialog({ open: true, modal: true })
    const { controller } = buildController(dialog)
    dialog.showModal = () => assert.fail("showModal() must not run again")

    assert.doesNotThrow(() => controller.open())
  })

  it("closes the dialog and restores dragging before Turbo caches the page", () => {
    const dialog = new FakeDialog()
    const { controller, element } = buildController(dialog)
    controller.open()

    controller.closeBeforeCache()

    assert.equal(dialog.open, false)
    assert.equal(element.getAttribute("draggable"), "true")
  })
})
