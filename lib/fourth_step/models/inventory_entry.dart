import 'package:hive/hive.dart';

part 'inventory_entry.g.dart';

/// Category types for 4th Step inventory entries
/// Each category has different labels but uses the same internal field structure
@HiveType(typeId: 14)
enum InventoryCategory {
  @HiveField(0)
  resentment,  // Default - "I'm resentful at", "The cause", etc.
  
  @HiveField(1)
  fear,        // "I'm fearful of", "Why do I have the fear?", etc.
  
  @HiveField(2)
  harms,       // "Who did I hurt?", "What did I do?", etc.
  
  @HiveField(3)
  sexualHarms; // "Who did I hurt?", "What did I do?", etc. (sexual context)
}

@HiveType(typeId: 0)
class InventoryEntry extends HiveObject {
  @HiveField(0)
  String? resentment;  // Field 1: "I'm resentful at" / "I'm fearful of" / "Who did I hurt?"

  @HiveField(1)
  String? reason;      // Field 2: "The cause" / "Why do I have the fear?" / "What did I do?"

  @HiveField(2)
  String? affect;      // Field 3: "Affects my" (same for all categories)

  @HiveField(3)
  String? part;        // Field 4: "My part" (same for all categories)

  @HiveField(4)
  String? defect;      // Field 5: "Shortcoming(s)" (same for all categories)

  @HiveField(5)
  String? _iAmId;       // DEPRECATED: Single I Am ID for backwards compatibility only
                        // Use iAmIds instead. Kept for Hive migration compatibility.

  @HiveField(6)
  InventoryCategory? category;  // Category type (defaults to resentment for backward compatibility)

  @HiveField(7)
  List<String>? iAmIds;  // Multiple I Am definition IDs (new field)

  InventoryEntry(
    this.resentment,
    this.reason,
    this.affect,
    this.part,
    this.defect, {
    String? iAmId,
    this.iAmIds,
    this.category,
  }) : _iAmId = iAmId {
    // Migration: if old single iAmId is set but iAmIds is empty, migrate it
    if (_iAmId != null && _iAmId!.isNotEmpty && _iAmId != 'null' && (iAmIds == null || iAmIds!.isEmpty)) {
      iAmIds = [_iAmId!];
    }
    // Sync: if iAmIds is set, ensure _iAmId has the first value for backwards compatibility
    if (iAmIds != null && iAmIds!.isNotEmpty) {
      _iAmId = iAmIds!.first;
    }
  }

  /// Get the first I Am ID (for backwards compatibility with old versions)
  /// Returns the first ID from iAmIds, or falls back to legacy _iAmId
  String? get iAmId {
    if (iAmIds != null && iAmIds!.isNotEmpty) {
      return iAmIds!.first;
    }
    return _iAmId;
  }

  /// Set a single I Am ID (for backwards compatibility)
  /// This sets the first item in iAmIds
  set iAmId(String? value) {
    if (value == null || value.isEmpty || value == 'null') {
      // If clearing, keep other iAmIds if any
      if (iAmIds != null && iAmIds!.isNotEmpty) {
        iAmIds!.removeAt(0);
        if (iAmIds!.isEmpty) iAmIds = null;
      }
      _iAmId = null;
    } else {
      if (iAmIds == null || iAmIds!.isEmpty) {
        iAmIds = [value];
      } else {
        iAmIds![0] = value;
      }
      _iAmId = value; // Keep in sync for backwards compatibility
    }
  }

  /// Get all I Am IDs (returns empty list if none)
  List<String> get effectiveIAmIds => iAmIds ?? (_iAmId != null && _iAmId!.isNotEmpty && _iAmId != 'null' ? [_iAmId!] : []);

  /// Get the effective category (defaults to resentment for backward compatibility)
  InventoryCategory get effectiveCategory => category ?? InventoryCategory.resentment;

  // Safe getters that provide empty strings for null values
  String get safeResentment => resentment ?? '';
  String get safeReason => reason ?? '';
  String get safeAffect => affect ?? '';
  String get safePart => part ?? '';
  String get safeDefect => defect ?? '';
  
  // Convenience getters with new names
  String? get myTake => part;
  set myTake(String? value) => part = value;
  
  String? get shortcomings => defect;
  set shortcomings(String? value) => defect = value;

  // JSON serialization
  // NOTE: We export BOTH iAmId (first ID for backwards compatibility) AND iAmIds (full list)
  // This ensures old versions can still read the first I Am while new versions get all
  Map<String, dynamic> toJson() {
    final firstIAmId = iAmId; // Uses getter which returns first from iAmIds or legacy _iAmId
    final allIAmIds = effectiveIAmIds;
    
    return {
      'resentment': resentment,
      'reason': reason,
      'affect': affect,
      'part': part,
      'defect': defect,
      // Always include first iAmId for backwards compatibility with old versions
      if (firstIAmId != null && firstIAmId != 'null') 'iAmId': firstIAmId,
      // Include full list if there are multiple I Ams
      if (allIAmIds.isNotEmpty) 'iAmIds': allIAmIds,
      if (category != null) 'category': category!.name,  // Store as string for JSON compatibility
    };
  }

  factory InventoryEntry.fromJson(Map<String, dynamic> json) {
    // Parse iAmIds list (new format)
    List<String>? parsedIAmIds;
    if (json['iAmIds'] != null) {
      final iAmIdsList = json['iAmIds'] as List<dynamic>;
      parsedIAmIds = iAmIdsList
          .where((id) => id != null && id != 'null')
          .map((id) => id as String)
          .toList();
      if (parsedIAmIds.isEmpty) parsedIAmIds = null;
    }
    
    // Handle legacy single iAmId (for backwards compatibility)
    final iAmIdValue = json['iAmId'];
    final String? parsedIAmId = (iAmIdValue == null || iAmIdValue == 'null') ? null : iAmIdValue as String?;
    
    // If we have iAmIds, use those; otherwise fall back to single iAmId
    // This ensures data from new versions (with iAmIds) is preserved,
    // while old data (with only iAmId) is also supported
    if (parsedIAmIds == null && parsedIAmId != null) {
      parsedIAmIds = [parsedIAmId];
    }
    
    // Parse category from string (backward compatible - null means resentment)
    InventoryCategory? parsedCategory;
    if (json['category'] != null) {
      final categoryStr = json['category'] as String;
      parsedCategory = InventoryCategory.values.where((c) => c.name == categoryStr).firstOrNull;
    }
    
    return InventoryEntry(
      json['resentment'] as String?,
      json['reason'] as String?,
      json['affect'] as String?,
      json['part'] as String?,
      json['defect'] as String?,
      iAmId: parsedIAmId, // Legacy field for Hive compatibility
      iAmIds: parsedIAmIds,
      category: parsedCategory,
    );
  }
}
