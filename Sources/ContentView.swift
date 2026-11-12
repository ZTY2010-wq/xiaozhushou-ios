import SwiftUI
import UIKit

struct RootView: View {
    @EnvironmentObject var store: ConfigStore

    @State private var connected: Bool = false
    @State private var showBar: Bool = false
    @State private var isLoading: Bool = false
    @State private var pageTitle: String = ""
    @State private var reloadToken: Int = 0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if connected, let url = store.resolvedURL {
                WebContainer(url: url,
                             isLoading: $isLoading,
                             title: $pageTitle,
                             reloadToken: reloadToken)
                    .ignoresSafeArea(.all)

                // 顶部热区：下滑/点击唤出工具条
                VStack {
                    Rectangle()
                        .fill(Color.white.opacity(0.001))
                        .frame(height: 44)
                        .onTapGesture { withAnimation(.easeOut(duration: 0.2)) { showBar.toggle() } }
                    Spacer()
                }
                .ignoresSafeArea(edges: .top)

                if showBar { toolBar.transition(.move(edge: .top)) }

                if isLoading { progressBar }
            } else {
                SetupView { connected = true }
            }
        }
        .onAppear {
            if store.autoConnect && store.hasTarget && store.mode == .stream {
                connected = true
            }
        }
    }

    private var progressBar: some View {
        VStack {
            ProgressView()
                .progressViewStyle(.linear)
                .tint(.blue)
                .padding(.top, 2)
            Spacer()
        }
        .ignoresSafeArea(edges: .top)
    }

    private var toolBar: some View {
        VStack {
            HStack(spacing: 10) {
                Text(showBar && !pageTitle.isEmpty ? pageTitle : (store.target.isEmpty ? "未连接" : store.target))
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer(minLength: 4)

                Button {
                    reloadToken &+= 1
                } label: {
                    Text("刷新").font(.system(size: 13, weight: .semibold))
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)

                Button {
                    connected = false
                    showBar = false
                } label: {
                    Text("设置").font(.system(size: 13, weight: .semibold))
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(.ultraThinMaterial)
            .overlay(Rectangle().frame(height: 0.5).foregroundColor(.white.opacity(0.12)), alignment: .bottom)

            Spacer()
        }
        .ignoresSafeArea(edges: .top)
    }
}

// MARK: - 配置页

struct SetupView: View {
    @EnvironmentObject var store: ConfigStore
    let onConnect: () -> Void

    @State private var draft: String = ""
    @State private var mode: ConfigStore.Mode = .stream
    @State private var err: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                VStack(alignment: .leading, spacing: 14) {
                    Text("连接方式").font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.gray).textCase(.uppercase)

                    Picker("", selection: $mode) {
                        ForEach(ConfigStore.Mode.allCases) { m in
                            Text(m.title).tag(m)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: mode) { m in store.mode = m }

                    TextField(draftPlaceholder, text: $draft)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .keyboardType(.URL)
                        .padding(13)
                        .background(Color(white: 0.09))
                        .cornerRadius(11)
                        .overlay(RoundedRectangle(cornerRadius: 11)
                            .stroke(Color.white.opacity(0.09), lineWidth: 1))
                        .foregroundColor(.white)

                    if let err = err {
                        Text(err).font(.system(size: 12)).foregroundColor(.orange)
                    }

                    Button {
                        connect()
                    } label: {
                        Text("连接").font(.system(size: 16, weight: .bold))
                            .frame(maxWidth: .infinity).padding(.vertical, 13)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                }
                .padding(16)
                .background(Color(white: 0.078))
                .cornerRadius(14)
                .overlay(RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.white.opacity(0.07), lineWidth: 1))

                hints

                Spacer(minLength: 24)
            }
            .padding(.horizontal, 20)
            .padding(.top, 34)
        }
        .background(Color(red: 0.043, green: 0.051, blue: 0.063).ignoresSafeArea())
        .onAppear { mode = store.mode; draft = store.target }
    }

    private var draftPlaceholder: String {
        mode.placeholder
    }

    private var header: some View {
        HStack(spacing: 13) {
            RoundedRectangle(cornerRadius: 14)
                .fill(LinearGradient(colors: [Color(red: 0.16, green: 0.42, blue: 0.69),
                                              Color(red: 0.23, green: 0.63, blue: 0.99)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 54, height: 54)
                .overlay(Text("助").font(.system(size: 25, weight: .bold)).foregroundColor(.white))
                .shadow(color: Color.blue.opacity(0.35), radius: 12, y: 5)

            VStack(alignment: .leading, spacing: 3) {
                Text("小助手").font(.system(size: 21, weight: .bold)).foregroundColor(.white)
                Text("iPhone 串流壳 · 远程操控安卓机")
                    .font(.system(size: 12)).foregroundColor(.gray)
            }
            Spacer()
        }
    }

    private var hints: some View {
        VStack(alignment: .leading, spacing: 11) {
            hintRow("1", "先在安卓机上跑起小助手，PC / NAS 上跑 ws-scrcpy。")
            hintRow("2", "两端装 Tailscale 登录同账号，免公网端口直接互通。")
            hintRow("3", "这里填 ws-scrcpy 的地址，进入页面再填安卓的 IP:5555。")
            hintRow("4", "也可切到「原生 App Scheme」直接唤起 ToDesk / RustDesk。")
        }
    }

    private func hintRow(_ n: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(n)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.blue)
                .frame(width: 18, height: 18)
                .background(Circle().fill(Color.blue.opacity(0.14)))
            Text(text).font(.system(size: 12.5)).foregroundColor(Color(white: 0.62))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func connect() {
        let t = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { err = "先填一个地址"; return }

        if mode == .app {
            store.mode = .app
            store.target = t
            if let u = URL(string: t) {
                UIApplication.shared.open(u)
            }
            err = nil
            return
        }

        // 补全 scheme 并校验
        var s = t
        if !s.lowercased().hasPrefix("http://") && !s.lowercased().hasPrefix("https://") {
            s = "http://" + s
        }
        guard URL(string: s) != nil else { err = "地址格式不对"; return }

        store.mode = .stream
        store.target = s
        err = nil
        onConnect()
    }
}
