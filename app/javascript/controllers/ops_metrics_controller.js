import { Controller } from "@hotwired/stimulus"

// The round trip is what an op costs, and the server log sees only half of it.
// The wait is split where the browser can see the split: what the server took
// to answer, and what Turbo and layout took to put the answer on the screen.
export default class extends Controller {
  request(event) {
    this.op = new URL(event.detail.url).searchParams.get("op")
    this.sent = new TextEncoder().encode(String(event.detail.fetchOptions.body)).length
    this.askedAt = performance.now()
  }

  response(event) {
    this.answeredAt = performance.now()
    this.received = event.detail.fetchResponse.response.clone().blob().then((body) => body.size)
  }

  report() {
    requestAnimationFrame(async () => {
      const drawnAt = performance.now()

      console.log(
        `[ops] ${this.op.padEnd(18)} ↑ ${size(this.sent)}  ↓ ${size(await this.received)}` +
        `   server ${duration(this.answeredAt - this.askedAt)}` +
        `   render ${duration(drawnAt - this.answeredAt)}` +
        `   total ${duration(drawnAt - this.askedAt)}`
      )
    })
  }
}

function size(bytes) {
  if (bytes < 1024) return `${bytes} B`
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} kB`

  return `${(bytes / 1024 / 1024).toFixed(2)} MB`
}

function duration(milliseconds) {
  return `${Math.round(milliseconds)} ms`.padStart(7)
}
