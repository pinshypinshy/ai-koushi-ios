/** リンクの移動を止め、押された URL をページに渡す。ブラウザで開くかは Swift が決める（§3.2） */
export function listenLinkTaps(onTap: (url: string) => void): void {
  document.addEventListener('click', (event) => {
    const anchor = event.target instanceof Element ? event.target.closest('a[href]') : null
    if (!(anchor instanceof HTMLAnchorElement)) return
    event.preventDefault()
    onTap(anchor.href)
  })
}
