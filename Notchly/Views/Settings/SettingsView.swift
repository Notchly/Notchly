//
//  SettingsView.swift
//  Notchly
//
//  Created by user on 16.03.2026.
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject var settingsManager: SettingsManager
    @State private var selectedSection: SettingsSection = .about
    @State private var searchText = ""

    var body: some View {
        HStack(spacing: 0) {
            sidebar
                .frame(width: 220)

            detail
        }
        .frame(width: 860, height: 680, alignment: .top)
        .background(SettingsBackground())
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .ignoresSafeArea(.container, edges: .top)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 16) {
            searchField

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    sidebarGroup(
                        title: "Application",
                        sections: [.about, .general]
                    )

                    sidebarGroup(
                        title: "Media & Files",
                        sections: [.music]
                    )

                    sidebarGroup(
                        title: "System",
                        sections: [.battery]
                    )
                }
            }

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.top, 46)
        .padding(.bottom, 16)
        .background(.black.opacity(0.12))
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(.white.opacity(0.08))
                .frame(width: 1)
        }
    }

    private var detail: some View {
        VStack(spacing: 0) {
            topBar

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    selectedContent
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding(.horizontal, 30)
                .padding(.top, 14)
                .padding(.bottom, 32)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var topBar: some View {
        HStack(spacing: 8) {
            HStack(spacing: 0) {
                Button {
                    selectPreviousSection()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .frame(width: 32, height: 36)
                }

                Divider()
                    .frame(height: 20)
                    .opacity(0.35)

                Button {
                    selectNextSection()
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 18, weight: .semibold))
                        .frame(width: 32, height: 36)
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .background(.black.opacity(0.16))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            VStack(alignment: .leading) {
                Text(selectedSection.rawValue)
                    .font(.system(size: 15, weight: .medium))

            }

            Spacer()

            if selectedSection == .about {
               EmptyView()
            } else {
                Button("Reset") {
                    resetSelectedSection()
                }
                .buttonStyle(.plain)
                .font(.system(size: 14, weight: .medium))
                .padding(.horizontal, 16)
                .frame(height: 36)
                .background(.black.opacity(0.18))
                .clipShape(RoundedRectangle(cornerRadius: 19, style: .continuous))
            }
        }
        .padding(.leading, 22)
        .padding(.trailing, 18)
        .padding(.top, 0)
        .padding(.bottom, 14)
        .frame(height: 70, alignment: .center)
        .background(.black.opacity(0.06))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(.white.opacity(0.07))
                .frame(height: 1)
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)

            TextField("Search", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 15, weight: .medium))
        }
        .padding(.horizontal, 12)
        .frame(height: 36)
        .background(.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func sidebarGroup(title: String, sections: [SettingsSection]) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)

            ForEach(sections.filter(matchesSearch)) { section in
                sidebarButton(section)
            }
        }
    }

    private func sidebarButton(_ section: SettingsSection) -> some View {
        Button {
            selectedSection = section
        } label: {
            HStack(spacing: 6) {
                SettingsSidebarIconView(
                    systemName: section.iconName,
                    backgroundColor: section.iconColor
                )

                Text(section.rawValue)
                    .font(.system(size: 14, weight: .regular))

                Spacer()
            }
            .padding(.horizontal, 10)
            .frame(height: 38)
            .contentShape(Rectangle())
            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(selectedSection == section ? Color.accentColor.opacity(0.65) : Color.clear)
            }
            .foregroundStyle(selectedSection == section ? .white : .primary)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var selectedContent: some View {
        switch selectedSection {
        case .general:
            GeneralSettingsView(settingsManager: settingsManager)

        case .battery:
            BatterySettingsView(settingsManager: settingsManager)

        case .music:
            MusicSettingsView(settingsManager: settingsManager)
            
        case .about:
              AboutSettingsView()
          }
    }

    private func matchesSearch(_ section: SettingsSection) -> Bool {
        searchText.isEmpty ||
        section.rawValue.localizedCaseInsensitiveContains(searchText) ||
        section.subtitle.localizedCaseInsensitiveContains(searchText)
    }

    private func selectPreviousSection() {
        let sections = SettingsSection.allCases
        guard let index = sections.firstIndex(of: selectedSection) else { return }

        let previousIndex = index == sections.startIndex
            ? sections.index(before: sections.endIndex)
            : sections.index(before: index)

        selectedSection = sections[previousIndex]
    }

    private func selectNextSection() {
        let sections = SettingsSection.allCases
        guard let index = sections.firstIndex(of: selectedSection) else { return }

        let nextIndex = sections.index(after: index) == sections.endIndex
            ? sections.startIndex
            : sections.index(after: index)

        selectedSection = sections[nextIndex]
    }

    private func resetSelectedSection() {
        withAnimation(.easeInOut(duration: 0.18)) {
            switch selectedSection {
            case .about:
                break
            case .general:
                settingsManager.resetGeneralSettings()
            case .battery:
                settingsManager.resetBatterySettings()
            case .music:
                settingsManager.resetMusicSettings()
            }
        }
    }
}
