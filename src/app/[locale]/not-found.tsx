import Link from "next/link";

export default function NotFound() {
  return (
    <section className="panel">
      <h1>Page not found</h1>
      <p>The page you requested does not exist.</p>
      <Link href="/ja">ホームへ戻る / Back home</Link>
    </section>
  );
}
