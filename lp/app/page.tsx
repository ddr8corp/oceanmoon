export default function Home() {
  return (
    <div className="min-h-screen bg-white text-gray-900 font-[var(--font-geist-sans)]">
      {/* Header */}
      <header className="border-b border-gray-100">
        <div className="max-w-4xl mx-auto px-6 py-5 flex items-center justify-between">
          <span className="text-base font-semibold tracking-tight">
            シンプル文字起こし
          </span>
          <a
            href="https://www.ddr8.co.jp/"
            target="_blank"
            rel="noopener noreferrer"
            className="text-sm text-gray-500 hover:text-gray-900 transition-colors"
          >
            サポート
          </a>
        </div>
      </header>

      <main>
        {/* Hero */}
        <section className="max-w-4xl mx-auto px-6 py-24 text-center">
          <p className="text-sm font-medium text-gray-500 mb-4 tracking-widest uppercase">
            iOS App
          </p>
          <h1 className="text-5xl font-bold tracking-tight mb-4 leading-tight">
            シンプル文字起こし
          </h1>
          <p className="text-xl text-gray-500 mb-12">
            リアルタイム音声文字起こしアプリ
          </p>

          {/* App Store Badge Placeholder */}
          <div className="flex justify-center">
            <div className="inline-flex items-center gap-3 bg-black text-white rounded-xl px-6 py-3.5 cursor-not-allowed select-none">
              <svg
                width="24"
                height="24"
                viewBox="0 0 24 24"
                fill="currentColor"
                aria-hidden="true"
              >
                <path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.8-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M13 3.5c.73-.83 1.94-1.46 2.94-1.5.13 1.17-.34 2.35-1.04 3.19-.69.85-1.83 1.51-2.95 1.42-.15-1.15.41-2.35 1.05-3.11z" />
              </svg>
              <div className="text-left">
                <p className="text-xs leading-none mb-0.5 opacity-80">
                  Download on the
                </p>
                <p className="text-lg font-semibold leading-none">App Store</p>
              </div>
            </div>
          </div>
          <p className="text-xs text-gray-400 mt-3">
            近日公開予定 &mdash; iOS 26.0以降、iPhone対応
          </p>
        </section>

        {/* Divider */}
        <div className="max-w-4xl mx-auto px-6">
          <hr className="border-gray-100" />
        </div>

        {/* Features */}
        <section className="max-w-4xl mx-auto px-6 py-24">
          <h2 className="text-2xl font-bold mb-16 text-center tracking-tight">
            機能
          </h2>
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-px bg-gray-100 border border-gray-100 rounded-2xl overflow-hidden">
            {[
              {
                title: "リアルタイム文字起こし",
                description:
                  "タイムスタンプ付きで音声をリアルタイムにテキスト化。話した内容をすぐに確認できます。",
              },
              {
                title: "スピーカー音声も認識",
                description:
                  "デバイスのスピーカーから流れる音声も文字起こし可能。オンラインミーティングや動画の書き起こしにも対応。",
              },
              {
                title: "完全オンデバイス処理",
                description:
                  "すべての音声認識はデバイス上で完結。インターネット接続は不要で、オフライン環境でも利用できます。",
              },
              {
                title: "セッション履歴",
                description:
                  "過去の文字起こしセッションを保存・一覧表示。必要なときにいつでも確認できます。",
              },
              {
                title: "編集・共有",
                description:
                  "文字起こし結果をアプリ内で編集し、テキストとして簡単に共有できます。",
              },
              {
                title: "画面スリープ防止",
                description:
                  "録音中は画面がスリープしないよう自動的に制御。長時間の会議や講義でも安心して使えます。",
              },
            ].map((feature) => (
              <div key={feature.title} className="bg-white p-8">
                <h3 className="text-base font-semibold mb-2">
                  {feature.title}
                </h3>
                <p className="text-sm text-gray-500 leading-relaxed">
                  {feature.description}
                </p>
              </div>
            ))}
          </div>
        </section>

        {/* Divider */}
        <div className="max-w-4xl mx-auto px-6">
          <hr className="border-gray-100" />
        </div>

        {/* Privacy Policy */}
        <section className="max-w-4xl mx-auto px-6 py-24" id="privacy">
          <h2 className="text-2xl font-bold mb-10 tracking-tight">
            プライバシーポリシー
          </h2>
          <div className="space-y-8 text-sm text-gray-600 leading-relaxed max-w-2xl">
            <div>
              <h3 className="font-semibold text-gray-900 mb-2">
                データの収集について
              </h3>
              <p>
                シンプル文字起こしは、いかなる個人情報も収集しません。氏名、メールアドレス、デバイスID、位置情報などのユーザー識別情報は一切取得しません。
              </p>
            </div>
            <div>
              <h3 className="font-semibold text-gray-900 mb-2">
                音声データの取り扱い
              </h3>
              <p>
                録音された音声およびその文字起こし結果はすべてデバイス内にのみ保存されます。音声データが外部サーバーに送信されることはありません。
              </p>
            </div>
            <div>
              <h3 className="font-semibold text-gray-900 mb-2">
                オンデバイス処理
              </h3>
              <p>
                音声認識処理はAppleのオンデバイス機械学習フレームワークを使用しており、すべての処理がデバイス上で完結します。ネットワーク接続を必要とせず、インターネット経由でデータが送受信されることはありません。
              </p>
            </div>
            <div>
              <h3 className="font-semibold text-gray-900 mb-2">
                サードパーティへのデータ提供
              </h3>
              <p>
                ユーザーデータを第三者に販売・提供・共有することはありません。
              </p>
            </div>
            <div>
              <h3 className="font-semibold text-gray-900 mb-2">
                ポリシーの変更
              </h3>
              <p>
                プライバシーポリシーに変更が生じた場合は、このページに掲載します。最終更新日：2026年3月18日
              </p>
            </div>
          </div>
        </section>

        {/* Divider */}
        <div className="max-w-4xl mx-auto px-6">
          <hr className="border-gray-100" />
        </div>

        {/* Support */}
        <section className="max-w-4xl mx-auto px-6 py-24" id="support">
          <h2 className="text-2xl font-bold mb-4 tracking-tight">サポート</h2>
          <p className="text-sm text-gray-500 mb-8 leading-relaxed max-w-xl">
            ご質問、バグ報告、機能リクエストは下記よりお問い合わせください。
          </p>
          <a
            href="https://www.ddr8.co.jp/"
            target="_blank"
            rel="noopener noreferrer"
            className="inline-flex items-center gap-2 bg-black text-white text-sm font-medium px-5 py-3 rounded-lg hover:bg-gray-800 transition-colors"
          >
            お問い合わせ
          </a>
        </section>
      </main>

      {/* Footer */}
      <footer className="border-t border-gray-100">
        <div className="max-w-4xl mx-auto px-6 py-8 flex flex-col sm:flex-row items-center justify-between gap-4">
          <p className="text-xs text-gray-400">
            &copy; 2026 ddr8 co., ltd. All rights reserved.
          </p>
          <nav className="flex gap-6">
            <a
              href="#privacy"
              className="text-xs text-gray-400 hover:text-gray-900 transition-colors"
            >
              プライバシーポリシー
            </a>
            <a
              href="#support"
              className="text-xs text-gray-400 hover:text-gray-900 transition-colors"
            >
              サポート
            </a>
          </nav>
        </div>
      </footer>
    </div>
  );
}
