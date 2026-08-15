import Link from "next/link";

export default function GlobalNotFound() {
  return (
    <html lang="en">
      <body>
        <main className="main-content">
          <section className="panel">
            <h1>Page not found</h1>
            <p>The page you requested does not exist.</p>
            <Link href="/ja">Back home</Link>
          </section>
        </main>
      </body>
    </html>
  );
}
