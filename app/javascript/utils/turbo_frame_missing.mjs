// Turbo throws TurboFrameMissingError and leaves the frame empty when a
// response has no matching <turbo-frame>. Two causes reach users: an error
// page from the proxy during a short outage, and a redirect to the login page
// after the session expires.
export function handleTurboFrameMissing(event, { notifyError }) {
  const { response, visit } = event.detail;

  if (!response.ok) {
    event.preventDefault();
    notifyError({ frame_id: event.target.id, status: response.status });
  } else if (response.redirected) {
    event.preventDefault();
    visit(response);
  }
}
