// Selector for a dialog open as a modal. Selector APIs throw a SyntaxError
// on `:modal` before Chrome 105 and Safari 15.6. There, an open dialog counts
// instead: DS::Dialog opens every dialog with showModal().
export const MODAL_DIALOG = supportsModal() ? "dialog:modal" : "dialog[open]";

function supportsModal() {
  try {
    document.createElement("dialog").matches(":modal");
    return true;
  } catch {
    return false;
  }
}
