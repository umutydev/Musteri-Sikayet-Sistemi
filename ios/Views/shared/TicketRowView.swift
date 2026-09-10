import SwiftUI

struct TicketRowView: View {
    let ticket: Ticket

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("#\(ticket.referenceNo)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                StatusBadge(status: ticket.status)
            }

            Text(ticket.subject)
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(AppTheme.navy)
                .multilineTextAlignment(.leading)
                .lineLimit(2)

            Text(ticket.description)
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            Divider()

            HStack {
                Image(systemName: "calendar")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                Text(ticket.createdAt.formatted(date: .abbreviated, time: .omitted))
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                Spacer()
                Image(systemName: "arrow.right")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct StatusBadge: View {
    let status: TicketStatus

    var body: some View {
        Text(status.displayName)
            .font(.system(size: 13, weight: .semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(status.color.opacity(0.15))
            .foregroundStyle(status.color)
            .clipShape(Capsule())
    }
}
