import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var keyCount: Int
    @Binding var useColors: Bool
    @Binding var useSoundOnly: Bool

    let keyCountOptions = [5, 7, 8, 13]

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Number of keys")
                        .font(.headline)
                        .foregroundColor(.secondary)

                    HStack(spacing: 12) {
                        ForEach(keyCountOptions, id: \.self) { count in
                            Button(action: {
                                keyCount = count
                            }) {
                                Text("\(count)")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(keyCount == count ? .white : .primary)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 12)
                                    .background(
                                        keyCount == count ? Color.blue : Color(.systemGray6)
                                    )
                                    .cornerRadius(8)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Use colors")
                        .font(.headline)
                        .foregroundColor(.secondary)

                    Toggle("", isOn: $useColors)
                        .labelsHidden()
                }
                .padding(.horizontal, 20)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Use sound only")
                        .font(.headline)
                        .foregroundColor(.secondary)

                    Toggle("", isOn: $useSoundOnly)
                        .labelsHidden()
                }
                .padding(.horizontal, 20)

                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
