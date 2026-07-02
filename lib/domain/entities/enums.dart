/// Kind of a catalog/custom node in the learning tree.
enum NodeKind { category, sefer, leaf }

/// The atomic unit a leaf is measured in.
enum UnitLabel { perek, daf, amud, siman, halacha, page, custom }

/// What a [LearningEvent] records.
///
/// * [done]     — a unit was learned.
/// * [undone]   — a previously-learned unit was un-marked.
/// * [reviewed] — a chazara (review) pass over a unit.
enum EventAction { done, undone, reviewed }
