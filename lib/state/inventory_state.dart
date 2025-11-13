import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/inventory_entry.dart';

/// Core state management for the inventory application
/// Follows the principles of separation of concerns and single responsibility
class InventoryState extends ChangeNotifier {
  late Box<InventoryEntry> _box;
  InventoryEntry? _editingEntry;
  int? _editingIndex;

  // Getters for accessing state
  Box<InventoryEntry> get entries => _box;
  InventoryEntry? get editingEntry => _editingEntry;
  int? get editingIndex => _editingIndex;
  bool get isEditing => _editingIndex != null;
  int get entryCount => _box.length;

  /// Initialize the state with the Hive box
  void initialize(Box<InventoryEntry> box) {
    _box = box;
  }

  /// Start editing an entry at the given index
  void startEditing(int index) {
    if (index >= 0 && index < _box.length) {
      _editingIndex = index;
      _editingEntry = _box.getAt(index);
      notifyListeners();
    }
  }

  /// Cancel editing and clear the editing state
  void cancelEditing() {
    _editingIndex = null;
    _editingEntry = null;
    notifyListeners();
  }

  /// Save an entry (either create new or update existing)
  Future<bool> saveEntry(InventoryEntry entry) async {
    try {
      if (isEditing && _editingIndex != null) {
        await _box.putAt(_editingIndex!, entry);
      } else {
        await _box.add(entry);
      }
      
      // Clear editing state after successful save
      _editingIndex = null;
      _editingEntry = null;
      
      notifyListeners();
      return true;
    } catch (e) {
      // Handle error appropriately
      debugPrint('Error saving entry: $e');
      return false;
    }
  }

  /// Delete an entry at the given index
  Future<bool> deleteEntry(int index) async {
    try {
      if (index >= 0 && index < _box.length) {
        await _box.deleteAt(index);
        
        // If we were editing this entry, clear the editing state
        if (_editingIndex == index) {
          _editingIndex = null;
          _editingEntry = null;
        } else if (_editingIndex != null && _editingIndex! > index) {
          // Adjust editing index if necessary
          _editingIndex = _editingIndex! - 1;
        }
        
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error deleting entry: $e');
      return false;
    }
  }

  /// Clear all entries
  Future<bool> clearAllEntries() async {
    try {
      await _box.clear();
      _editingIndex = null;
      _editingEntry = null;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error clearing entries: $e');
      return false;
    }
  }

  /// Get entry at specific index safely
  InventoryEntry? getEntryAt(int index) {
    if (index >= 0 && index < _box.length) {
      return _box.getAt(index);
    }
    return null;
  }
}