import SwiftUI
import SwiftData
import VoxlueData
import VoxlueDesign
import VoxlueServices

/// 一个声音圈的详情 —— 成员、圈内胶囊、发邀请。
struct CircleDetailView: View {
    @Environment(ServiceContainer.self) private var services

    let circle: VoxlueData.Circle

    @State private var invitation: ShareInvitation?
    @State private var isMakingInvitation = false
    @State private var errorText: String?

    private var members: [CircleMember] {
        (circle.members ?? []).sorted { $0.joinedAt < $1.joinedAt }
    }

    private var metaLine: String {
        let count = (circle.members ?? []).count
        let date = circle.createdAt.formatted(date: .abbreviated, time: .omitted)
        return "\(count) 位成员 · 建于 \(date)"
    }

    var body: some View {
        List {
            Section {
                headerCard
            }
            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: VoxlueSpacing.md, trailing: 0))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            Section {
                CircleCapsulesList(circleID: circle.id)
            } header: {
                sectionHeader("圈里的声音")
            }

            Section {
                ForEach(members) { member in
                    HStack(spacing: VoxlueSpacing.md) {
                        Text(CircleEmoji.memberEmoji(forName: member.name))
                            .font(.system(size: 24))
                            .frame(width: 36, height: 36)
                            .background(VoxlueColor.paperShadow.opacity(0.4), in: Circle())
                        VStack(alignment: .leading, spacing: VoxlueSpacing.xs) {
                            Text(member.name.isEmpty ? "（无名）" : member.name)
                                .font(VoxlueTypography.serifBody)
                                .foregroundStyle(VoxlueColor.ink)
                        }
                        Spacer()
                        Text(member.role == .owner ? "圈主" : "成员")
                            .font(VoxlueTypography.meta)
                            .foregroundStyle(VoxlueColor.graphite)
                    }
                }
            } header: {
                sectionHeader("成员（\(members.count)）")
            }

            Section {
                Button {
                    makeInvitation()
                } label: {
                    Label("邀请新成员", systemImage: "person.crop.circle.badge.plus")
                        .font(VoxlueTypography.serifBody)
                        .foregroundStyle(VoxlueColor.vermillion)
                }
                .disabled(isMakingInvitation)

                if let errorText {
                    // 错误用 ink 主色 + 朱红警告 icon 区分，避免与朱红 CTA 抢色。
                    Label {
                        Text(errorText)
                            .font(VoxlueTypography.caption)
                            .foregroundStyle(VoxlueColor.ink)
                    } icon: {
                        Image(systemName: "exclamationmark.circle")
                            .foregroundStyle(VoxlueColor.vermillion)
                    }
                }
            } footer: {
                Text("生成一个链接，用 iMessage 或任意方式发给对方；对方点开即可加入。")
                    .font(VoxlueTypography.caption)
                    .foregroundStyle(VoxlueColor.darkroomGray)
            }
        }
        .scrollContentBackground(.hidden)
        .background(VoxlueColor.paper.ignoresSafeArea())
        .navigationTitle(circle.name.isEmpty ? "声音圈" : circle.name)
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if isMakingInvitation {
                ProgressView("正在生成邀请…")
                    .tint(VoxlueColor.vermillion)
                    .padding(VoxlueSpacing.lg)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: VoxlueRadius.card))
            }
        }
        .sheet(item: $invitation) { invitation in
            ShareInvitationSheet(url: invitation.url)
        }
    }

    private var headerCard: some View {
        PaperCard {
            HStack(alignment: .top, spacing: VoxlueSpacing.md) {
                VStack(alignment: .leading, spacing: VoxlueSpacing.xs) {
                    Text(circle.name.isEmpty ? "（未命名的圈）" : circle.name)
                        .font(VoxlueTypography.serifTitle)
                        .foregroundStyle(VoxlueColor.ink)
                    Text(metaLine)
                        .font(VoxlueTypography.meta)
                        .foregroundStyle(VoxlueColor.graphite)
                }
                Spacer(minLength: VoxlueSpacing.sm)
                Text("圈")
                    .font(VoxlueTypography.meta)
                    .tracking(2)
                    .foregroundStyle(VoxlueColor.vermillion)
                    .padding(.horizontal, VoxlueSpacing.sm)
                    .padding(.vertical, VoxlueSpacing.xs)
                    .overlay(
                        RoundedRectangle(cornerRadius: VoxlueRadius.stamp, style: .continuous)
                            .strokeBorder(VoxlueColor.vermillion, lineWidth: 1.5)
                    )
                    .rotationEffect(.degrees(-8))
                    .opacity(0.88)
            }
        }
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(VoxlueTypography.caption)
            .foregroundStyle(VoxlueColor.graphite)
            .textCase(nil)
    }

    private func makeInvitation() {
        isMakingInvitation = true
        errorText = nil
        Task {
            do {
                invitation = try await services.circleService.makeInvitation(for: circle)
            } catch CircleServiceError.cloudKitUnavailable {
                errorText = "iCloud 暂时连不上，邀请没生成。"
            } catch {
                errorText = "生成邀请失败：\(error.localizedDescription)"
            }
            isMakingInvitation = false
        }
    }
}

/// 圈内胶囊浏览 —— 直接用 @Query 按 circleID 过滤本地库。
private struct CircleCapsulesList: View {
    @Query private var capsules: [VoxlueData.Capsule]

    init(circleID: UUID) {
        _capsules = Query(
            filter: #Predicate<VoxlueData.Capsule> { $0.circleID == circleID },
            sort: \.createdAt, order: .reverse
        )
    }

    var body: some View {
        if capsules.isEmpty {
            Text("圈里还没有声音。装裱一枚胶囊时选这个圈，它就会出现在这里。")
                .font(VoxlueTypography.caption)
                .foregroundStyle(VoxlueColor.graphite)
        } else {
            ForEach(capsules) { capsule in
                NavigationLink {
                    CapsuleDetailView(capsule: capsule)
                } label: {
                    // 跟 HomeView 最近预览同款：CapsuleRow 缩 75%，再用固定高度
                    // 把视觉收回到 topLeading，避免 scaleEffect 留出半截空白。
                    CapsuleRow(capsule: capsule)
                        .scaleEffect(0.75, anchor: .topLeading)
                        .frame(height: 168, alignment: .top)
                        .clipped()
                }
                .buttonStyle(.plain)
            }
        }
    }
}

#Preview {
    NavigationStack {
        CircleDetailView(circle: {
            let c = VoxlueData.Circle(name: "家", ownerID: "me")
            c.members = [
                CircleMember(name: "我", userRecordID: "me", role: .owner),
                CircleMember(name: "奶奶", userRecordID: "nana", role: .member),
            ]
            return c
        }())
    }
    .environment(ServiceContainer.preview())
    .modelContainer(for: VoxlueData.Capsule.self, inMemory: true)
}
