//
//  WhatsNewView.swift
//  Clique
//
//  Created by Rod Tavangar on 3/4/25.
//

import SwiftUI

struct WhatsNewView: View {
    @Binding var isPresented: Bool
    
    private let releases: [(version: String, changes: [String])] = [
        ("2.0.0 – February 23rd, 2026", [
            "Apple Photos integration, Cloud Cliques, and iMessage Extension",
            "All above functionality iOS 26 only and in beta"
        ]),
        ("1.8.0 – December 23rd, 2025", [
            "User flicks library"
        ]),
        ("1.7.4 – November 26th, 2025", [
            "Tap and hold flick previews for menu options (context menu)",
            "Selected photos view respects library order (was random)",
            "Background music pause bug fix",
            "iOS 26.1 splash screen hang bug fix"
        ]),
        ("1.7.3 – November 17th, 2025", [
            "iOS 26.1 TabView state change bug fix"
        ]),
        ("1.7.2 - November 14th, 2025", [
            "Crash fix when trying to upload many flicks",
            "Time display fix in collection detail view",
            "Image zoom bug fixes",
            "Collection deep links"
        ]),
        ("1.7.1 – November 5th, 2025", [
            "Live Activity for uploading"
        ]),
        ("1.7.0 – November 3rd, 2025", [
            "Live Photos and Videos with associated functionality",
            "CDN (Content Delivery Network) for faster image and video loading",
            "Design changes",
            "Bug fixes and performance improvements"
        ]),
        ("1.6.5 – September 29th, 2025", [
            "Yellow no entry bug fix",
            "Image caching improvements"
        ]),
        ("1.6.4 – September 9, 2025", [
            "Inbox notifications bug fix",
            "Image performance improvements"
        ]),
        ("1.6.3 – August 30, 2025", [
            "Grid view for flicks feed",
            "Design fixes and performance improvements"
        ]),
        ("1.6.2 – August 28, 2025", [
            "Bug fixes and performance improvements"
        ]),
        ("1.6.1 – August 18, 2025", [
            "Bug fixes"
        ]),
        ("1.6.0 – August 16, 2025", [
            "Smooth profile scroll (iOS18+)",
            "Custom photos picker with drag to select (iOS18+)",
            "Frontend caching",
            "Tab bar animation and titles",
            "Upload progress bug fixes"
        ]),
        ("1.5.0 – July 17, 2025", [
            "TAP PROFILE PICTURES TO SEE EXPANDED",
            "New upload progress tracker",
            "Flick date extracted from location, if no location then device time zone",
            "Edit button on collection gallery view",
            "Create clique button on empty feeds",
            "Invite contact now actually texts that contact"
        ]),
        ("1.4.2 – July 2, 2025", [
            "Tap bottom tab to refresh infinite feed",
            "Tapping notification when app is terminated will open notifications center",
            "Bug fixes and qol improvements"
        ]),
        ("1.4.1 – June 27, 2025", [
            "Liking on infinite feed fix",
            "Nav to collection from infinite feed"
        ]),
        ("1.4.0 – June 27, 2025", [
            "INFINITE FLICK FEED",
            "NOTIFICATIONS",
            "Single screen clique creator",
            "Private collection feed fix",
            "Comment notifications tracked",
            "Self comment notifications removed"
        ]),
        ("1.3.8 – May 24, 2025", [
            "Show med qual if cached from gallery (qol)"
        ]),
        ("1.3.7 – May 23, 2025", [
            "iOS17 photo library upload fix"
        ]),
        ("1.3.6 – May 22, 2025", [
            "Image caching and retrieval optimizations",
            "UI for blocking users and cliques",
            "Collection feed cell loading frame same size as image",
            "QOL improvements"
        ]),
        ("1.3.5 – May 17, 2025", [
            "Moved actions from plus to star button",
            "“Add flicks” button on collection feed cell gives you the option for from camera or library",
            "Fixed member list showing gaps bug",
            "Edit clique button on profile for easier access"
        ]),
        ("1.3.4 – May 9, 2025", [
            "Names appear under My Cliques",
            "My Collections will remember which view format you choose",
            "APN token shenanigans",
            "Recent users pfp fix"
        ]),
        ("1.3.3 – April 30, 2025", [
            "Analytics tracking for sign ups and app opens",
            "Optimized image uploading by bounding concurrency using a semaphore"
        ]),
        ("1.3.2 – April 29, 2025", [
            "NEW: see who liked a flick by tapping on the number next to the heart icon",
            "Optimized how images are downloaded from iCloud",
            "Check notification device token against app storage for any inconsistencies",
            "Added pinch zoom for preview carousel after choosing flicks to upload",
            "Bug fix for navigating away from inbox view (sheet wouldn’t dismiss)",
            "Push notifications might be entirely broken though...."
        ]),
        ("1.3.1 – April 10, 2025", [
            "Potential photo selection iCloud nonsense fix",
            "Push notifications for liked flick",
            "Performance improvements",
            "Connection for in-app notifications list, will be viewable next update",
        ]),
        ("1.3.0 – March 28, 2025", [
            "Tapping on a notification takes you to inbox as long as the app session is alive (so not from launch, maybe 1.5.0 type)",
            "Tap collections tab to scroll to top",
            "Edit collection bug fixes",
            "Fixed crash when adding flicks from feed",
            "Visual improvements"
        ]),
        ("1.2.0 – March 26, 2025", [
            "Delete flick from collection (must be in clique)",
            "Edit collection after creation",
            "Add flicks directly from feed",
            "New bottom tab bar and top bar",
            "Redesign",
            "Tapping on notification does something (?)"
        ]),
        ("1.1.0 – March 25, 2025", [
            "Start loading most recent home feed item and then fetch the next page. Doesn't work in clique hub for some reason so keeping that 5 for now",
            "Delete collection (must be in clique)",
            "Tooltip for sort in gallery view"
        ]),
        ("1.0.0 – March 14, 2025", [
            "Are we really here?",
            "Image loading fixed (I pray)",
            "Various improvements"
        ])
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("🕒 What's New")
                .font(.largeTitle.bold())
                .textPrimary()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(releases, id: \.version) { release in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(release.version)
                                .font(.title3.bold())
                            
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(release.changes, id: \.self) { change in
                                    Text("• \(change)")
                                        .font(.callout)
                                        .padding(.leading, 8)
                                }
                            }
                        }
                    }
                }
            }
            .scrollIndicators(.visible)
            .scrollBarIgnorePadding(24)
//            .fixedSize(horizontal: false, vertical: true)
            
            CliqueButton(type: .primary, text: "Close", fullWidth: true) {
                isPresented = false
            }
        }
        .frame(height: UIScreen.height / 2)
        .maxWidth(.leading)
        .padding(24)
        .background(Color(UIColor.systemGray5))
        .roundCorners(16)
        .padding(.horizontal, 8)
        .shadow(radius: 20)
    }
}

#Preview {
    WhatsNewView(isPresented: .constant(true))
}
