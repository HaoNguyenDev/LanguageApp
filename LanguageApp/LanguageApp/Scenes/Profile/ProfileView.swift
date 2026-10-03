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
}

struct ProfileView: View {
    @Environment(UserSettings.self) private var userSettings
    @Environment(PremiumManager.self) private var premium
    @Query private var activities: [DailyActivity]
    @Query(filter: #Predicate<VocabItem> { $0.srsDue != nil }) private var learnedItems: [VocabItem]
    @Query(filter: #Predicate<Lesson> { $0.isCompleted }) private var completedLessons: [Lesson]
    @Query(filter: #Predicate<CourseUnit> { $0.checkpointPassed }) private var passedUnits: [CourseUnit]

    var onOpenPaywall: VoidResult?

    @State private var isEditingName = false
    @State private var nameDraft = ""

    private var stats: ProfileStats {
        ProfileStats(streak: ProgressService.streak(from: activities),
                     totalXP: ProgressService.totalXP(from: activities),
                     todayXP: ProgressService.xp(on: .now, from: activities),
                     wordsLearned: learnedItems.count,
                     lessonsCompleted: completedLessons.count)
    }

    private var achievementStats: AchievementStats {
        AchievementService.stats(activities: activities,
                                 wordsLearned: learnedItems.count,
                                 lessonsCompleted: completedLessons.count,
                                 perfectLessonsFromHistory: completedLessons.filter { $0.bestAccuracy >= 0.999 }.count,
                                 checkpointsPassed: passedUnits.count)
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
                achievements(stats: achievementStats)
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

    private func achievements(stats: AchievementStats) -> some View {
        let theme = userSettings.theme
        let unlockedIds = Set(AchievementService.unlockedDates().keys)
        let isUnlocked: (Achievement) -> Bool = { unlockedIds.contains($0.id) || $0.isUnlocked(stats) }
        let unlockedCount = Achievement.all.filter(isUnlocked).count
        let ratio: (Achievement) -> Double = { achievement in
            let p = achievement.progress(stats)
            return Double(p.value) / Double(max(p.target, 1))
        }
        // Unlocked first, then the ones closest to being reached.
        let sorted = Achievement.all.sorted { a, b in
            let ua = isUnlocked(a), ub = isUnlocked(b)
            if ua != ub { return ua }
            return ratio(a) > ratio(b)
        }
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("achievements".localized())
                    .setFont(.bold, size: 20, color: theme.textColor)
                Spacer()
                Text("\(unlockedCount)/\(Achievement.all.count)")
                    .setFont(.bold, size: 15, color: theme.secondaryTextColor)
            }
            ForEach(sorted) { achievement in
                AchievementRow(achievement: achievement,
                               unlocked: isUnlocked(achievement),
                               progress: achievement.progress(stats))
            }
        }
    }
}

// MARK: - Achievement row

struct AchievementRow: View {
    @Environment(UserSettings.self) private var userSettings
    let achievement: Achievement
    let unlocked: Bool
    let progress: (value: Int, target: Int)

    var body: some View {
        let theme = userSettings.theme
        HStack(spacing: 14) {
            Image(systemName: achievement.icon)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(unlocked ? .white : theme.secondaryTextColor)
                .frame(width: 48, height: 48)
                .background(unlocked ? theme.xpColor : theme.lockedColor.opacity(0.5),
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(achievement.titleKey.localized())
                    .setFont(.bold, size: 16, color: theme.textColor)
                Text(achievement.descriptionKey.localized())
                    .setFont(.regular, size: 13, color: theme.secondaryTextColor)
                if !unlocked {
                    HStack(spacing: 8) {
                        LessonProgressBar(progress: Double(min(progress.value, progress.target)) / Double(progress.target),
                                          height: 8,
                                          color: theme.xpColor)
                        Text("\(min(progress.value, progress.target))/\(progress.target)")
                            .setFont(.semibold, size: 11, color: theme.secondaryTextColor)
                            .monospacedDigit()
                    }
                }
            }
            Spacer()
            if unlocked {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(theme.correctColor)
            }
        }
        .opacity(unlocked ? 1 : 0.75)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    ProfileView()
        .environment(UserSettings())
        .environment(PremiumManager())
        .modelContainer(PersistenceController.preview)
}
