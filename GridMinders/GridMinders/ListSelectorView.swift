import SwiftUI

struct ListSelectorView: View {
    @ObservedObject var fetcher: ReminderFetcher
    @Binding var isPresented: Bool

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("List Selection").font(.title2).bold()
                Spacer()
                Button("Done") { isPresented = false }
            }
            .padding(.bottom, 8)

            Toggle(isOn: $fetcher.useExclusion) {
                Text("Exclude selected lists (advanced)")
            }
            .onChange(of: fetcher.useExclusion) { _ in fetcher.saveUserSelection() }

            List(fetcher.calendars, id: \.calendarIdentifier) { cal in
                HStack {
                    if fetcher.useExclusion {
                        Toggle(isOn: Binding(
                            get: { fetcher.excludedCalendarIDs.contains(cal.calendarIdentifier) },
                            set: { checked in
                                if checked {
                                    fetcher.excludedCalendarIDs.insert(cal.calendarIdentifier)
                                } else {
                                    fetcher.excludedCalendarIDs.remove(cal.calendarIdentifier)
                                }
                                fetcher.saveUserSelection()
                            }
                        )) {
                            Text(cal.title)
                        }
                    } else {
                        Toggle(isOn: Binding(
                            get: { fetcher.includedCalendarIDs.contains(cal.calendarIdentifier) },
                            set: { checked in
                                if checked {
                                    fetcher.includedCalendarIDs.insert(cal.calendarIdentifier)
                                } else {
                                    fetcher.includedCalendarIDs.remove(cal.calendarIdentifier)
                                }
                                fetcher.saveUserSelection()
                            }
                        )) {
                            Text(cal.title)
                        }
                    }
                }
            }
            .frame(minHeight: 200)

            Spacer()
        }
        .padding()
        .frame(width: 350, height: 400)
    }
}
