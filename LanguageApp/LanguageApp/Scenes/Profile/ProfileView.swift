//
//  ProfileView.swift
//  LanguageApp
//
//  Stats: streak, XP, daily goal ring, weekly chart, achievements.
//

import SwiftUI
import SwiftData
import Charts

struct ProfileCoordinator: View {
    var navRouter: any NavRouterProtocol

    var body: some View {
        ProfileView(onOpenPaywall: {
            navRouter.showSheet(RouterView(routable: Router.Study.paywall))
        })
        .toolbar(.hidden, for: .navigationBar)
    }
}

struct ProfileStats {
    let streak: Int
    let totalXP: Int
    let todayXP: Int
    let wordsLearned: Int
    let lessonsCompleted: Int
    let hasPerfectLesson: Bool
}

struct ProfileView: View {
    @Environment(UserSettings.self) private var userSettings
    @Environment(PremiumManager.self) private var premium
    @Query private var activities: [DailyActivity]
    @Query(filter: #Predicate<VocabItem> { $0.srsDue != nil }) private var learnedItems: [VocabItem]
    @Query(filter: #Predicate<Lesson> { $0.isCompleted }) private var completedLessons: [Lesson]

    var onOpenPaywall: VoidResult?

    @State private var isEditingName = false
    @State private var nameDraft = ""

    private var stats: ProfileStats {
        ProfileStats(streak: ProgressService.streak(from: activities),
                     totalXP: ProgressService.totalXP(from: activities),
                     todayXP: ProgressService.xp(on: .now, from: activities),
                     wordsLearned: learnedItems.count,
                     lessonsCompleted: completedLessons.count,
                     hasPerfectLesson: completedLessons.contains { $0.bestAccuracy >= 0.999 })
    }

    var body: some View {
        let theme = userSettings.theme
        let stats = self.stats
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                header
                dailyGoalCard(stats: stats)
                statsGrid(stats: stats)
                weeklyChart
                achievements(stats: stats)
                if !premium.isPremium {
                    Button {
                        onOpenPaywall?()
                    } label: {
                        HStack {
                            Image(systemName: "crown.fill")
                            Text("upgrade_to_plus".localized()).font(mainFont.bold(16))
                            Spacer()
                            Image(systemName: "chevron.right")
                        }
                        .foregroundStyle(.white)
                        .padding(18)
                        .background(LinearGradient(colors: [theme.primaryColor, Color(hex: "#EC4899")],
                                                   startPoint: .leading, endPoint: .trailing),
                                    in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
        }
        .tabBarSafeArea()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .setDefaultBackground()
        .alert("edit_name".localized(), isPresented: $isEditingName) {
            TextField("your_name".localized(), text: $nameDraft)
            Button("save".localized()) {
                let trimmed = nameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                userSettings.username = trimmed.isEmpty ? nil : trimmed
            }
            Button("cancel".localized(), role: .cancel) {}
        }
    }

    // MARK: - Sections

    private var header: some View {
        let theme = userSettings.theme
        let name = userSettings.username ?? "learner".localized()
        return HStack(spacing: 16) {
            Text(String(name.prefix(1)).uppercased())
                .setFont(.bold, size: 30, color: .white)
                .frame(width: 68, height: 68)
                .background(theme.primaryColor, in: Circle())
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(name).setFont(.bold, size: 24, color: theme.textColor)
                    if premium.isPremium {
                        Image(systemName: "crown.fill").foregroundStyle(theme.xpColor)
                    }
                }
                Button {
                    nameDraft = userSettings.username ?? ""
                    isEditingName = true
                } label: {
                    Label("edit_name".localized(), systemImage: "pencil")
                        .font(mainFont.semibold(14))
                        .foregroundStyle(theme.primaryColor)
                }
            }
            Spacer()
        }
    }

    private func dailyGoalCard(stats: ProfileStats) -> some View {
        let theme = userSettings.theme
        let goal = max(userSettings.dailyGoalXP, 1)
        let progress = min(Double(stats.todayXP) / Double(goal), 1)
        return CardContainer {
            HStack(spacing: 20) {
                ZStack {
                    Circle().stroke(theme.borderColor, lineWidth: 10)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(theme.xpColor, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Image(systemName: progress >= 1 ? "checkmark" : "target")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(theme.xpColor)
                }
                .frame(width: 72, height: 72)
                VStack(alignment: .leading, spacing: 4) {
                    Text("daily_goal".localized())
                        .setFont(.bold, size: 18, color: theme.textColor)
                    Text("\(stats.todayXP) / \(goal) XP")
                        .setFont(.semibold, size: 16, color: theme.secondaryTextColor)
                    if progress >= 1 {
                        Text("daily_goal_reached".localized())
                            .setFont(.semibold, size: 14, color: theme.correctShadowColor)
                    }
                }
                Spacer()
            }
        }
    }

    private func statsGrid(stats: ProfileStats) -> some View {
        let theme = userSettings.theme
        let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
        return LazyVGrid(columns: columns, spacing: 12) {
            statTile(icon: "flame.fill", value: "\(stats.streak)", label: "day_streak".localized(), color: theme.streakColor)
            statTile(icon: "bolt.fill", value: "\(stats.totalXP)", label: "total_xp".localized(), color: theme.xpColor)
            statTile(icon: "character.book.closed.fill", value: "\(stats.wordsLearned)", label: "words_learned".localized(), color: theme.primaryColor)
            statTile(icon: "checkmark.seal.fill", value: "\(stats.lessonsCompleted)", label: "lessons_completed".localized(), color: theme.correctColor)
        }
    }

    private func statTile(icon: String, value: String, label: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 0) {
                Text(value).setFont(.bold, size: 20, color: userSettings.theme.textColor)
                Text(label).setFont(.regular, size: 12, color: userSettings.theme.secondaryTextColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(userSettings.theme.cardBgColor, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var weeklyChart: some View {
        let theme = userSettings.theme
        let history = ProgressService.xpHistory(days: 7, from: activities)
        return CardContainer {
            VStack(alignment: .leading, spacing: 12) {
                Text("this_week".localized())
                    .setFont(.bold, size: 18, color: theme.textColor)
                Chart {
                    ForEach(history, id: \.date) { entry in
                        BarMark(x: .value("Day", entry.date, unit: .day),
                                y: .value("XP", entry.xp))
                        .foregroundStyle(Calendar.current.isDateInToday(entry.date) ? theme.xpColor : theme.primaryColor)
                        .cornerRadius(6)
                    }
                    RuleMark(y: .value("Goal", userSettings.dailyGoalXP))
                        .foregroundStyle(theme.secondaryTextColor.opacity(0.5))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { _ in
                        AxisValueLabel(format: .dateTime.weekday(.narrow), centered: true)
                    }
                }
                .frame(height: 160)
            }
        }
    }

    private func achievements(stats: ProfileStats) -> some View {
        let theme = userSettings.theme
        return VStack(alignment: .leading, spacing: 12) {
            Text("achievements".localized())
                .setFont(.bold, size: 20, color: theme.textColor)
            ForEach(Achievement.all) { achievement in
                let unlocked = achievement.isUnlocked(stats)
                HStack(spacing: 14) {
                    Image(systemName: achievement.icon)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(unlocked ? .white : theme.secondaryTextColor)
                        .frame(width: 48, height: 48)
                        .background(unlocked ? theme.xpColor : theme.lockedColor.opacity(0.5),
                                    in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(achievement.titleKey.localized())
                            .setFont(.bold, size: 16, color: theme.textColor)
                        Text(achievement.descriptionKey.localized())
                            .setFont(.regular, size: 13, color: theme.secondaryTextColor)
                    }
                    Spacer()
                    if unlocked {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(theme.correctColor)
                    }
                }
                .opacity(unlocked ? 1 : 0.7)
            }
        }
    }
}

// MARK: - Achievements

struct Achievement: Identifiable {
    let id: String
    let icon: String
    let titleKey: String
    let descriptionKey: String
    let isUnlocked: (ProfileStats) -> Bool

    static let all: [Achievement] = [
        Achievement(id: "first_lesson", icon: "flag.checkered", titleKey: "ach_first_lesson", descriptionKey: "ach_first_lesson_desc") { $0.lessonsCompleted >= 1 },
        Achievement(id: "perfect", icon: "star.fill", titleKey: "ach_perfect", descriptionKey: "ach_perfect_desc") { $0.hasPerfectLesson },
        Achievement(id: "streak3", icon: "flame.fill", titleKey: "ach_streak_3", descriptionKey: "ach_streak_3_desc") { $0.streak >= 3 },
        Achievement(id: "streak7", icon: "flame.circle.fill", titleKey: "ach_streak_7", descriptionKey: "ach_streak_7_desc") { $0.streak >= 7 },
        Achievement(id: "words50", icon: "character.book.closed.fill", titleKey: "ach_words_50", descriptionKey: "ach_words_50_desc") { $0.wordsLearned >= 50 },
        Achievement(id: "xp500", icon: "bolt.circle.fill", titleKey: "ach_xp_500", descriptionKey: "ach_xp_500_desc") { $0.totalXP >= 500 }
    ]
}

#Preview {
    ProfileView()
        .environment(UserSettings())
        .environment(PremiumManager())
        .modelContainer(PersistenceController.preview)
}
