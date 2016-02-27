/* Copyright 2016 Stanford University, NVIDIA Corporation
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#include "legion.h"
#include "runtime.h"
#include "legion_ops.h"
#include "legion_tasks.h"
#include "region_tree.h"
#include "legion_spy.h"
#include "legion_profiling.h"
#include "legion_instances.h"
#include "legion_views.h"

namespace Legion {
  namespace Internal {

    LEGION_EXTERN_LOGGER_DECLARATIONS

    /////////////////////////////////////////////////////////////
    // Layout Description 
    /////////////////////////////////////////////////////////////

    //--------------------------------------------------------------------------
    LayoutDescription::LayoutDescription(const FieldMask &mask,
                                         LayoutConstraints *con,
                                         FieldSpaceNode *own)
      : allocated_fields(mask), constraints(con), owner(own) 
    //--------------------------------------------------------------------------
    {
      layout_lock = Reservation::create_reservation();
    }

    //--------------------------------------------------------------------------
    LayoutDescription::LayoutDescription(const LayoutDescription &rhs)
      : allocated_fields(rhs.allocated_fields), 
        constraints(rhs.constraints), owner(rhs.owner)
    //--------------------------------------------------------------------------
    {
      // should never be called
      assert(false);
    }

    //--------------------------------------------------------------------------
    LayoutDescription::~LayoutDescription(void)
    //--------------------------------------------------------------------------
    {
      memoized_offsets.clear();
      layout_lock.destroy_reservation();
      layout_lock = Reservation::NO_RESERVATION;
    }

    //--------------------------------------------------------------------------
    LayoutDescription& LayoutDescription::operator=(
                                                   const LayoutDescription &rhs)
    //--------------------------------------------------------------------------
    {
      // should never be called
      assert(false);
      return *this;
    }

    //--------------------------------------------------------------------------
    void* LayoutDescription::operator new(size_t count)
    //--------------------------------------------------------------------------
    {
      return legion_alloc_aligned<LayoutDescription,true/*bytes*/>(count);
    }

    //--------------------------------------------------------------------------
    void LayoutDescription::operator delete(void *ptr)
    //--------------------------------------------------------------------------
    {
      free(ptr);
    }

    //--------------------------------------------------------------------------
    void LayoutDescription::compute_copy_offsets(const FieldMask &copy_mask,
                                                 PhysicalInstance instance,
                                   std::vector<Domain::CopySrcDstField> &fields)
    //--------------------------------------------------------------------------
    {
      uint64_t hash_key = copy_mask.get_hash_key();
      size_t added_offset_count = 0;
      bool found_in_cache = false;
      // First check to see if we've memoized this result 
      {
        AutoLock o_lock(layout_lock,1,false/*exclusive*/);
        std::map<LEGION_FIELD_MASK_FIELD_TYPE,
                 LegionVector<OffsetEntry>::aligned >::const_iterator
          finder = memoized_offsets.find(hash_key);
        if (finder != memoized_offsets.end())
        {
          for (LegionVector<OffsetEntry>::aligned::const_iterator it = 
                finder->second.begin(); it != finder->second.end(); it++)
          {
            if (it->offset_mask == copy_mask)
            {
              fields.insert(fields.end(),it->offsets.begin(),it->offsets.end());
              found_in_cache = true;
              added_offset_count = it->offsets.size();
              break;
            }
          }
        }
      }
      if (found_in_cache)
      {
#ifdef DEBUG_HIGH_LEVEL
        assert(added_offset_count <= fields.size());
#endif
        // Go through and fill in all the annonymous instances
        for (unsigned idx = fields.size() - added_offset_count;
              idx < fields.size(); idx++)
        {
          fields[idx].inst = instance;
        }
        // Now we're done
        return;
      }
      // It is absolutely imperative that these infos be added in
      // the order in which they appear in the field mask so that 
      // they line up in the same order with the source/destination infos
      // (depending on the calling context of this function)
#ifdef DEBUG_HIGH_LEVEL
      int pop_count = 0;
#endif
      std::vector<Domain::CopySrcDstField> local;
      for (std::map<unsigned,FieldID>::const_iterator it = 
            field_indexes.begin(); it != field_indexes.end(); it++)
      {
        if (copy_mask.is_set(it->first))
        {
          std::map<FieldID,Domain::CopySrcDstField>::const_iterator finder = 
            field_infos.find(it->second);
#ifdef DEBUG_HIGH_LEVEL
          assert(finder != field_infos.end());
          pop_count++;
#endif
          fields.push_back(finder->second);
          // Because instances are annonymous in layout descriptions
          // we have to fill them in as we add them to fields
          fields.back().inst = instance;
          local.push_back(finder->second);
        }
      }
#ifdef DEBUG_HIGH_LEVEL
      // Make sure that we added exactly the number of infos as
      // there were fields set in the bit mask
      assert(pop_count == FieldMask::pop_count(copy_mask));
#endif
      // Add this to the results
      AutoLock o_lock(layout_lock);
      std::map<LEGION_FIELD_MASK_FIELD_TYPE,
               LegionVector<OffsetEntry>::aligned >::iterator
        finder = memoized_offsets.find(hash_key);
      if (finder == memoized_offsets.end())
        memoized_offsets[hash_key].push_back(OffsetEntry(copy_mask,local));
      else
        finder->second.push_back(OffsetEntry(copy_mask,local));
    }

    //--------------------------------------------------------------------------
    void LayoutDescription::compute_copy_offsets(FieldID fid, 
        PhysicalInstance instance, std::vector<Domain::CopySrcDstField> &fields)
    //--------------------------------------------------------------------------
    {
      std::map<FieldID,Domain::CopySrcDstField>::const_iterator
        finder = field_infos.find(fid);
#ifdef DEBUG_HIGH_LEVEL
      assert(finder != field_infos.end());
#endif
      fields.push_back(finder->second);
      // Since instances are annonymous in layout descriptions we
      // have to fill them in when we add the field info
      fields.back().inst = instance;
    }

    //--------------------------------------------------------------------------
    void LayoutDescription::compute_copy_offsets(
                                   const std::vector<FieldID> &copy_fields, 
                                   PhysicalInstance instance,
                                   std::vector<Domain::CopySrcDstField> &fields)
    //--------------------------------------------------------------------------
    {
      for (std::vector<FieldID>::const_iterator it = copy_fields.begin();
            it != copy_fields.end(); it++)
      {
        std::map<FieldID,Domain::CopySrcDstField>::const_iterator
          finder = field_infos.find(*it);
#ifdef DEBUG_HIGH_LEVEL
        assert(finder != field_infos.end());
#endif
        fields.push_back(finder->second);
        // Since instances are annonymous in layout descriptions we
        // have to fill them in when we add the field info
        fields.back().inst = instance;
      }
    }

    //--------------------------------------------------------------------------
    bool LayoutDescription::has_field(FieldID fid) const
    //--------------------------------------------------------------------------
    {
      return (field_infos.find(fid) != field_infos.end());
    }

    //--------------------------------------------------------------------------
    void LayoutDescription::has_fields(std::map<FieldID,bool> &to_test) const
    //--------------------------------------------------------------------------
    {
      for (std::map<FieldID,bool>::iterator it = to_test.begin();
            it != to_test.end(); it++)
      {
        if (field_infos.find(it->first) != field_infos.end())
          it->second = true;
        else
          it->second = false;
      }
    }

    //--------------------------------------------------------------------------
    void LayoutDescription::remove_space_fields(std::set<FieldID> &filter) const
    //--------------------------------------------------------------------------
    {
      std::vector<FieldID> to_remove;
      for (std::set<FieldID>::const_iterator it = filter.begin();
            it != filter.end(); it++)
      {
        if (field_infos.find(*it) != field_infos.end())
          to_remove.push_back(*it);
      }
      if (!to_remove.empty())
      {
        for (std::vector<FieldID>::const_iterator it = to_remove.begin();
              it != to_remove.end(); it++)
          filter.erase(*it);
      }
    }

    //--------------------------------------------------------------------------
    void LayoutDescription::add_field_info(FieldID fid, unsigned index,
                                           size_t offset, size_t field_size,
                                           CustomSerdezID serdez_id)
    //--------------------------------------------------------------------------
    {
#ifdef DEBUG_HIGH_LEVEL
      assert(field_infos.find(fid) == field_infos.end());
      assert(field_indexes.find(index) == field_indexes.end());
#endif
      // Use annonymous instances when creating these field infos since
      // we specifying layouts independently of any one instance
      field_infos[fid] = Domain::CopySrcDstField(PhysicalInstance::NO_INST,
                                                 offset, field_size, serdez_id);
      field_indexes[index] = fid;
#ifdef DEBUG_HIGH_LEVEL
      assert(offset_size_map.find(offset) == offset_size_map.end());
#endif
      offset_size_map[offset] = field_size;
    }

    //--------------------------------------------------------------------------
    const Domain::CopySrcDstField& LayoutDescription::find_field_info(
                                                              FieldID fid) const
    //--------------------------------------------------------------------------
    {
      std::map<FieldID,Domain::CopySrcDstField>::const_iterator finder = 
        field_infos.find(fid);
#ifdef DEBUG_HIGH_LEVEL
      assert(finder != field_infos.end());
#endif
      return finder->second;
    }

    //--------------------------------------------------------------------------
    size_t LayoutDescription::get_total_field_size(void) const
    //--------------------------------------------------------------------------
    {
      size_t result = 0;
      // Add up all the field sizes
      for (std::map<FieldID,Domain::CopySrcDstField>::const_iterator it = 
            field_infos.begin(); it != field_infos.end(); it++)
      {
        result += (it->second.size);
      }
      return result;
    }

    //--------------------------------------------------------------------------
    void LayoutDescription::get_fields(std::vector<FieldID>& fields) const
    //--------------------------------------------------------------------------
    {
      // order field ids by their offsets by inserting them to std::map
      std::map<unsigned, FieldID> offsets;
      for (std::map<FieldID, Domain::CopySrcDstField>::const_iterator it =
            field_infos.begin(); it != field_infos.end(); ++it)
        offsets[it->second.offset] = it->first;
      for (std::map<unsigned, FieldID>::const_iterator it = offsets.begin();
           it != offsets.end(); ++it)
        fields.push_back(it->second);
    }

    //--------------------------------------------------------------------------
    bool LayoutDescription::match_layout(const FieldMask &mask,
                         const LayoutConstraintSet &candidate_constraints) const
    //--------------------------------------------------------------------------
    {
      if (allocated_fields != mask)
        return false;
      if (!constraints->equal(candidate_constraints))
        return false;
      return true;
    }

    //--------------------------------------------------------------------------
    bool LayoutDescription::match_layout(LayoutDescription *rhs) const
    //--------------------------------------------------------------------------
    {
      return match_layout(rhs->allocated_fields, *rhs->constraints); 
    }

    //--------------------------------------------------------------------------
    void LayoutDescription::set_descriptor(FieldDataDescriptor &desc,
                                           unsigned fid_idx) const
    //--------------------------------------------------------------------------
    {
      std::map<unsigned,FieldID>::const_iterator idx_finder = 
        field_indexes.find(fid_idx);
#ifdef DEBUG_HIGH_LEVEL
      assert(idx_finder != field_indexes.end());
#endif
      std::map<FieldID,Domain::CopySrcDstField>::const_iterator finder = 
        field_infos.find(idx_finder->second);
#ifdef DEBUG_HIGH_LEVEL
      assert(finder != field_infos.end());
#endif
      desc.field_offset = finder->second.offset;
      desc.field_size = finder->second.size;
    }

    //--------------------------------------------------------------------------
    void LayoutDescription::pack_layout_description(Serializer &rez,
                                                    AddressSpaceID target)
    //--------------------------------------------------------------------------
    {
      RezCheck z(rez);
      // Do a quick check to see if the target already has the layout
      // We don't need to hold a lock here since if we lose the race
      // we will just send the layout twice and everything will be
      // resolved on the far side
      if (known_nodes.contains(target))
      {
        rez.serialize<bool>(true);
        // If it is already on the remote node, then we only
        // need to the necessary information to identify it
        DistributedID constraint_did = constraints->send_constraints(target);
        rez.serialize(constraint_did);
        rez.serialize(allocated_fields);
      }
      else
      {
        rez.serialize<bool>(false);
        DistributedID constraint_did = constraints->send_constraints(target);
        rez.serialize(constraint_did);
        rez.serialize(allocated_fields);
        rez.serialize<size_t>(field_infos.size());
#ifdef DEBUG_HIGH_LEVEL
        assert(field_infos.size() == field_indexes.size());
#endif
        for (std::map<unsigned,FieldID>::const_iterator it = 
              field_indexes.begin(); it != field_indexes.end(); it++)
        {
          std::map<FieldID,Domain::CopySrcDstField>::const_iterator finder = 
            field_infos.find(it->second);
#ifdef DEBUG_HIGH_LEVEL
          assert(finder != field_infos.end());
#endif
          rez.serialize(it->second);
          rez.serialize(finder->second.offset);
          rez.serialize(finder->second.size);
          rez.serialize(finder->second.serdez_id);
        }
      }
    }

    //--------------------------------------------------------------------------
    void LayoutDescription::unpack_layout_description(Deserializer &derez)
    //--------------------------------------------------------------------------
    {
      size_t num_fields;
      derez.deserialize(num_fields);
      for (unsigned idx = 0; idx < num_fields; idx++)
      {
        FieldID fid;
        derez.deserialize(fid);
        unsigned index = owner->get_field_index(fid);
        field_indexes[index] = fid;
        Domain::CopySrcDstField &info = field_infos[fid];
        derez.deserialize(info.offset);
        derez.deserialize(info.size);
        derez.deserialize(info.serdez_id);
#ifdef DEBUG_HIGH_LEVEL
        assert(offset_size_map.find(info.offset) == offset_size_map.end());
#endif
        offset_size_map[info.offset] = info.size;
      }
    }

    //--------------------------------------------------------------------------
    void LayoutDescription::update_known_nodes(AddressSpaceID target)
    //--------------------------------------------------------------------------
    {
      // Hold the lock to get serial access to this data structure
      AutoLock l_lock(layout_lock);
      known_nodes.add(target);
    }

    //--------------------------------------------------------------------------
    /*static*/ LayoutDescription* LayoutDescription::
      handle_unpack_layout_description(Deserializer &derez,
                                 AddressSpaceID source, RegionNode *region_node)
    //--------------------------------------------------------------------------
    {
      DerezCheck z(derez);
      bool has_local;
      derez.deserialize(has_local);
      FieldSpaceNode *field_space_node = region_node->column_source;
      LayoutDescription *result = NULL;
      DistributedID constraint_did;
      derez.deserialize(constraint_did);
#ifdef DEBUG_HIGH_LEVEL
      LayoutConstraints *constraints = dynamic_cast<LayoutConstraints*>(
        region_node->context->runtime->find_distributed_collectable(
                                                            constraint_did));
#else
      LayoutConstraints *constraints = static_cast<LayoutConstraints*>(
        region_node->context->runtime->find_distributed_collectable(
                                                            constraint_did));
#endif
      FieldMask mask;
      derez.deserialize(mask);
      field_space_node->transform_field_mask(mask, source);
      if (has_local)
      {
        // If we have a local layout, then we should be able to find it
        result = field_space_node->find_layout_description(mask, constraints);
      }
      else
      {
        // Otherwise create a new layout description, 
        // unpack it, and then try registering it with
        // the field space node
        result = new LayoutDescription(mask, constraints, field_space_node);
        result->unpack_layout_description(derez);
        result = field_space_node->register_layout_description(result);
      }
#ifdef DEBUG_HIGH_LEVEL
      assert(result != NULL);
#endif
      // Record that the sender already has this layout
      // Only do this after we've registered the instance
      result->update_known_nodes(source);
      return result;
    }

    //--------------------------------------------------------------------------
    /*static*/ size_t LayoutDescription::compute_layout_volume(const Domain &d)
    //--------------------------------------------------------------------------
    {
      if (d.get_dim() == 0)
      {
        const Realm::ElementMask &mask = 
          d.get_index_space().get_valid_mask();
        return mask.get_num_elmts();
      }
      else
        return d.get_volume();
    }

    /////////////////////////////////////////////////////////////
    // PhysicalManager 
    /////////////////////////////////////////////////////////////

    //--------------------------------------------------------------------------
    PhysicalManager::PhysicalManager(RegionTreeForest *ctx, 
                                     MemoryManager *memory, DistributedID did,
                                     AddressSpaceID owner_space,
                                     AddressSpaceID local_space,
                                     RegionNode *node,
                                     PhysicalInstance inst, bool register_now)
      : DistributedCollectable(ctx->runtime, did, owner_space, 
                               local_space, register_now), 
        context(ctx), memory_manager(memory), region_node(node), instance(inst)
    //--------------------------------------------------------------------------
    {
      if (register_now)
        region_node->register_physical_manager(this);
      // If we are not the owner, add a resource reference
      if (!is_owner())
      {
        // Register it with the memory manager, the memory manager
        // on the owner node will handle this
        memory_manager->register_remote_instance(this);
        add_base_resource_ref(REMOTE_DID_REF);
      }
    }

    //--------------------------------------------------------------------------
    PhysicalManager::~PhysicalManager(void)
    //--------------------------------------------------------------------------
    {
      // Only do the unregistration if we were successfully registered
      if (registered_with_runtime)
        region_node->unregister_physical_manager(this);
      // If we're the owner remove our resource references
      if (is_owner())
      {
        UpdateReferenceFunctor<RESOURCE_REF_KIND,false/*add*/> functor(this);
        map_over_remote_instances(functor);
      }
      else
        memory_manager->unregister_remote_instance(this);
      if (is_owner() && instance.exists())
      {
        log_leak.warning("Leaking physical instance " IDFMT " in memory"
                               IDFMT "", instance.id, get_memory().id);
      }
    }

    //--------------------------------------------------------------------------
    void PhysicalManager::notify_active(void)
    //--------------------------------------------------------------------------
    {
#ifdef DEBUG_HIGH_LEVEL
      if (is_owner())
        assert(instance.exists());
#endif
      memory_manager->activate_instance(this);
      // If we are not the owner, send a reference
      if (!is_owner())
        send_remote_gc_update(owner_space, 1/*count*/, true/*add*/);
    }

    //--------------------------------------------------------------------------
    void PhysicalManager::notify_inactive(void)
    //--------------------------------------------------------------------------
    {
#ifdef DEBUG_HIGH_LEVEL
      if (is_owner())
        assert(instance.exists());
#endif
      memory_manager->deactivate_instance(this);
      if (!is_owner())
        send_remote_gc_update(owner_space, 1/*count*/, false/*add*/);
    }

    //--------------------------------------------------------------------------
    void PhysicalManager::notify_valid(void)
    //--------------------------------------------------------------------------
    {
      // No need to do anything
#ifdef DEBUG_HIGH_LEVEL
      if (is_owner())
        assert(instance.exists());
#endif
      memory_manager->validate_instance(this);
      // If we are not the owner, send a reference
      if (!is_owner())
        send_remote_valid_update(owner_space, 1/*count*/, true/*add*/);
    }

    //--------------------------------------------------------------------------
    void PhysicalManager::notify_invalid(void)
    //--------------------------------------------------------------------------
    {
#ifdef DEBUG_HIGH_LEVEL
      if (is_owner())
        assert(instance.exists());
#endif
      memory_manager->invalidate_instance(this);
      if (!is_owner())
        send_remote_valid_update(owner_space, 1/*count*/, false/*add*/);
    }

    //--------------------------------------------------------------------------
    void PhysicalManager::register_logical_top_view(UniqueID context_uid,
                                                    LogicalView *top_view)
    //--------------------------------------------------------------------------
    {
      // Co-opt the gc lock for synchronization
      AutoLock gc(gc_lock);
#ifdef DEBUG_HIGH_LEVEL
      assert(top_views.find(context_uid) == top_views.end());
#endif
      top_views[context_uid] = top_view;
    }

    //--------------------------------------------------------------------------
    void PhysicalManager::unregister_logical_top_view(LogicalView *top_view)
    //--------------------------------------------------------------------------
    {
      // Co-opt the gc lock for synchronization
      AutoLock gc(gc_lock);
      for (std::map<UniqueID,LogicalView*>::iterator it = top_views.begin();
            it != top_views.end(); it++)
      {
        if (it->second == top_view)
        {
          top_views.erase(it);
          return;
        }
      }
      assert(false); // should never get here
    }

    //--------------------------------------------------------------------------
    UniqueID PhysicalManager::find_context_uid(LogicalView *top_view) const
    //--------------------------------------------------------------------------
    {
      // Co-opt the gc lock for synchronization
      AutoLock gc(gc_lock,1,false/*exclusive*/);
      for (std::map<UniqueID,LogicalView*>::const_iterator it = 
            top_views.begin(); it != top_views.end(); it++)
      {
        if (it->second == top_view)
          return it->first;
      }
      assert(false); // should never get here
      return 0;
    }
  
    //--------------------------------------------------------------------------
    LogicalView* PhysicalManager::find_logical_top_view(
                                                     UniqueID context_uid) const
    //--------------------------------------------------------------------------
    {
      // Co-opt the gc lock for synchronization
      AutoLock gc(gc_lock,1,false/*exclusive*/);
      std::map<UniqueID,LogicalView*>::const_iterator finder = 
        top_views.find(context_uid);
#ifdef DEBUG_HIGH_LEVEL
      assert(finder != top_views.end());
#endif
      return finder->second;
    }

    //--------------------------------------------------------------------------
    bool PhysicalManager::meets_regions(
                                const std::vector<LogicalRegion> &regions) const
    //--------------------------------------------------------------------------
    {
      for (std::vector<LogicalRegion>::const_iterator it = 
            regions.begin(); it != regions.end(); it++)
      {
        // Check to see if the region tree IDs are the same
        if (it->get_tree_id() != region_node->handle.get_tree_id())
          return false;
        // Same region tree
        RegionNode *handle_node = context->get_node(*it);
        // Same node and we are done
        if (handle_node == region_node)
          continue;
        // At this point the manager node must be above the handle node
        // in order for it to still have a chance of being valid
        const unsigned inst_depth = region_node->row_source->depth;
        if (handle_node->row_source->depth <= inst_depth)
          return false;
        // Walk the handle node up until its depth is the same as the
        // node for this instance
        while (handle_node->row_source->depth > inst_depth)
        {
#ifdef DEBUG_HIGH_LEVEL
          assert(handle_node->parent != NULL);
#endif
          handle_node = handle_node->parent->parent;
        }
        if (handle_node != region_node)
          return false;
      }
      return true;
    }

    //--------------------------------------------------------------------------
    void PhysicalManager::perform_deletion(Event deferred_event) const
    //--------------------------------------------------------------------------
    {
#ifdef DEBUG_HIGH_LEVEL
      assert(is_owner());
#endif
      log_garbage.info("Deleting physical instance " IDFMT " in memory " 
                       IDFMT "", instance.id, memory_manager->memory.id);
#ifndef DISABLE_GC
      instance.destroy(deferred_event);
#endif
    }

    //--------------------------------------------------------------------------
    void PhysicalManager::set_garbage_collection_priority(MapperID mapper_id,
                                            Processor proc, GCPriority priority)
    //--------------------------------------------------------------------------
    {
      memory_manager->set_garbage_collection_priority(this, mapper_id,
                                                      proc, priority);
    }

    //--------------------------------------------------------------------------
    /*static*/ void PhysicalManager::delete_physical_manager(
                                                       PhysicalManager *manager)
    //--------------------------------------------------------------------------
    {
      if (manager->is_reduction_manager())
      {
        ReductionManager *reduc_manager = manager->as_reduction_manager();
        if (reduc_manager->is_list_manager())
          legion_delete(reduc_manager->as_list_manager());
        else
          legion_delete(reduc_manager->as_fold_manager());
      }
      else
        legion_delete(manager->as_instance_manager());
    }

    /////////////////////////////////////////////////////////////
    // InstanceManager 
    /////////////////////////////////////////////////////////////

    //--------------------------------------------------------------------------
    InstanceManager::InstanceManager(RegionTreeForest *ctx, DistributedID did,
                                     AddressSpaceID owner_space, 
                                     AddressSpaceID local_space,
                                     MemoryManager *mem, PhysicalInstance inst,
                                     RegionNode *node, LayoutDescription *desc, 
                                     Event u_event, unsigned dep, 
                                     bool reg_now, InstanceFlag flags)
      : PhysicalManager(ctx, mem, did, owner_space, local_space,
                        node, inst, reg_now), layout(desc), use_event(u_event), 
        depth(dep), instance_flags(flags)
    //--------------------------------------------------------------------------
    {
      // Add a reference to the layout
      layout->add_reference();
#ifdef LEGION_GC
      log_garbage.info("GC Instance Manager %ld " IDFMT " " IDFMT " ",
                        did, inst.id, mem.id);
#endif
    }

    //--------------------------------------------------------------------------
    InstanceManager::InstanceManager(const InstanceManager &rhs)
      : PhysicalManager(NULL, NULL, 0, 0, 0,
                        NULL, PhysicalInstance::NO_INST, false), 
        layout(NULL), use_event(Event::NO_EVENT), depth(0)
    //--------------------------------------------------------------------------
    {
      // should never be called
      assert(false);
    }

    //--------------------------------------------------------------------------
    InstanceManager::~InstanceManager(void)
    //--------------------------------------------------------------------------
    {
      if (layout->remove_reference())
        delete layout;
    }

    //--------------------------------------------------------------------------
    InstanceManager& InstanceManager::operator=(const InstanceManager &rhs)
    //--------------------------------------------------------------------------
    {
      // should never be called
      assert(false);
      return *this;
    }

    //--------------------------------------------------------------------------
    LegionRuntime::Accessor::RegionAccessor<
      LegionRuntime::Accessor::AccessorType::Generic>
        InstanceManager::get_accessor(void) const
    //--------------------------------------------------------------------------
    {
#ifdef DEBUG_HIGH_LEVEL
      assert(instance.exists());
#endif
      return instance.get_accessor();
    }

    //--------------------------------------------------------------------------
    LegionRuntime::Accessor::RegionAccessor<
      LegionRuntime::Accessor::AccessorType::Generic>
        InstanceManager::get_field_accessor(FieldID fid) const
    //--------------------------------------------------------------------------
    {
#ifdef DEBUG_HIGH_LEVEL
      assert(instance.exists());
      assert(layout != NULL);
#endif
      const Domain::CopySrcDstField &info = layout->find_field_info(fid);
      LegionRuntime::Accessor::RegionAccessor<
        LegionRuntime::Accessor::AccessorType::Generic> temp = 
                                                    instance.get_accessor();
      return temp.get_untyped_field_accessor(info.offset, info.size);
    }

    //--------------------------------------------------------------------------
    bool InstanceManager::is_reduction_manager(void) const
    //--------------------------------------------------------------------------
    {
      return false;
    }

    //--------------------------------------------------------------------------
    bool InstanceManager::is_instance_manager(void) const
    //--------------------------------------------------------------------------
    {
      return true;
    }

    //--------------------------------------------------------------------------
    InstanceManager* InstanceManager::as_instance_manager(void) const
    //--------------------------------------------------------------------------
    {
      return const_cast<InstanceManager*>(this);
    }

    //--------------------------------------------------------------------------
    ReductionManager* InstanceManager::as_reduction_manager(void) const
    //--------------------------------------------------------------------------
    {
      return NULL;
    }

    //--------------------------------------------------------------------------
    size_t InstanceManager::get_instance_size(void) const
    //--------------------------------------------------------------------------
    {
#ifdef DEBUG_HIGH_LEVEL
      assert(layout != NULL);
#endif
      size_t field_sizes = layout->get_total_field_size();
      size_t volume = 
        region_node->row_source->get_domain_blocking().get_volume();
      return (field_sizes * volume);
    }

    //--------------------------------------------------------------------------
    MaterializedView* InstanceManager::create_top_view(unsigned depth,
                                                       UniqueID ctx_uid)
    //--------------------------------------------------------------------------
    {
      DistributedID view_did = 
        context->runtime->get_available_distributed_id(false);
      MaterializedView *result = legion_new<MaterializedView>(context, view_did,
                                                context->runtime->address_space,
                                                context->runtime->address_space,
                                                region_node, this,
                                            ((MaterializedView*)NULL/*parent*/),
                                                depth, true/*register now*/,
                                                ctx_uid);
      return result;
    }

    //--------------------------------------------------------------------------
    void InstanceManager::compute_copy_offsets(const FieldMask &copy_mask,
                                  std::vector<Domain::CopySrcDstField> &fields)
    //--------------------------------------------------------------------------
    {
#ifdef DEBUG_HIGH_LEVEL
      assert(layout != NULL);
#endif
      // Pass in our physical instance so the layout knows how to specialize
      layout->compute_copy_offsets(copy_mask, instance, fields);
    }

    //--------------------------------------------------------------------------
    void InstanceManager::compute_copy_offsets(FieldID fid,
                                  std::vector<Domain::CopySrcDstField> &fields)
    //--------------------------------------------------------------------------
    {
#ifdef DEBUG_HIGH_LEVEL
      assert(layout != NULL);
#endif
      // Pass in our physical instance so the layout knows how to specialize
      layout->compute_copy_offsets(fid, instance, fields);
    }

    //--------------------------------------------------------------------------
    void InstanceManager::compute_copy_offsets(
                                  const std::vector<FieldID> &copy_fields,
                                  std::vector<Domain::CopySrcDstField> &fields)
    //--------------------------------------------------------------------------
    {
#ifdef DEBUG_HIGH_LEVEL
      assert(layout != NULL);
#endif
      // Pass in our physical instance so the layout knows how to specialize
      layout->compute_copy_offsets(copy_fields, instance, fields);
    }

    //--------------------------------------------------------------------------
    void InstanceManager::set_descriptor(FieldDataDescriptor &desc,
                                         unsigned fid_idx) const
    //--------------------------------------------------------------------------
    {
      // Fill in the information about our instance
      desc.inst = instance;
      // Ask the layout to fill in the information about field offset and size
      layout->set_descriptor(desc, fid_idx);
    }

    //--------------------------------------------------------------------------
    DistributedID InstanceManager::send_manager(AddressSpaceID target)
    //--------------------------------------------------------------------------
    {
      if (!has_remote_instance(target))
      {
        // No need to take the lock, duplicate sends are alright
        Serializer rez;
        {
          RezCheck z(rez);
          rez.serialize(did);
          rez.serialize(owner_space);
          rez.serialize(memory_manager->memory);
          rez.serialize(instance);
          rez.serialize(region_node->handle);
          rez.serialize(use_event);
          rez.serialize(depth);
          rez.serialize(instance_flags);
          layout->pack_layout_description(rez, target);
        }
        context->runtime->send_instance_manager(target, rez);
        update_remote_instances(target);
        // Finally we can update our known nodes
        // It's only safe to do this after the message
        // has been sent
        layout->update_known_nodes(target);
      }
      return did;
    }

    //--------------------------------------------------------------------------
    /*static*/ void InstanceManager::handle_send_manager(Runtime *runtime, 
                                     AddressSpaceID source, Deserializer &derez)
    //--------------------------------------------------------------------------
    {
      DerezCheck z(derez);
      DistributedID did;
      derez.deserialize(did);
      AddressSpaceID owner_space;
      derez.deserialize(owner_space);
      Memory mem;
      derez.deserialize(mem);
      PhysicalInstance inst;
      derez.deserialize(inst);
      LogicalRegion handle;
      derez.deserialize(handle);
      Event use_event;
      derez.deserialize(use_event);
      unsigned depth;
      derez.deserialize(depth);
      InstanceFlag flags;
      derez.deserialize(flags);
      RegionNode *target_node = runtime->forest->get_node(handle);
      LayoutDescription *layout = 
        LayoutDescription::handle_unpack_layout_description(derez, source, 
                                                            target_node);
      MemoryManager *memory = runtime->find_memory_manager(mem);
      InstanceManager *inst_manager = legion_new<InstanceManager>(
                                        runtime->forest, did, owner_space,
                                        runtime->address_space, memory, inst,
                                        target_node, layout, use_event,
                                        depth, false/*reg now*/, flags);
      if (!target_node->register_physical_manager(inst_manager))
      {
        if (inst_manager->remove_base_resource_ref(REMOTE_DID_REF))
          legion_delete(inst_manager);
      }
      else
      {
        inst_manager->register_with_runtime();
        inst_manager->update_remote_instances(source);
      }
    }

    //--------------------------------------------------------------------------
    bool InstanceManager::is_attached_file(void) const
    //--------------------------------------------------------------------------
    {
      return (instance_flags & ATTACH_FILE_FLAG);
    }

    /////////////////////////////////////////////////////////////
    // ReductionManager 
    /////////////////////////////////////////////////////////////

    //--------------------------------------------------------------------------
    ReductionManager::ReductionManager(RegionTreeForest *ctx, DistributedID did,
                                       FieldID f, AddressSpaceID owner_space, 
                                       AddressSpaceID local_space,
                                       MemoryManager *mem,PhysicalInstance inst,
                                       RegionNode *node, ReductionOpID red, 
                                       const ReductionOp *o, bool reg_now)
      : PhysicalManager(ctx, mem, did, owner_space, local_space,
                        node, inst, reg_now), 
        op(o), redop(red), logical_field(f)
    //--------------------------------------------------------------------------
    { 
    }

    //--------------------------------------------------------------------------
    ReductionManager::~ReductionManager(void)
    //--------------------------------------------------------------------------
    {
    }

    //--------------------------------------------------------------------------
    bool ReductionManager::is_reduction_manager(void) const
    //--------------------------------------------------------------------------
    {
      return true;
    }

    //--------------------------------------------------------------------------
    bool ReductionManager::is_instance_manager(void) const
    //--------------------------------------------------------------------------
    {
      return false;
    }

    //--------------------------------------------------------------------------
    InstanceManager* ReductionManager::as_instance_manager(void) const
    //--------------------------------------------------------------------------
    {
      return NULL;
    }

    //--------------------------------------------------------------------------
    ReductionManager* ReductionManager::as_reduction_manager(void) const
    //--------------------------------------------------------------------------
    {
      return const_cast<ReductionManager*>(this);
    }

    //--------------------------------------------------------------------------
    bool ReductionManager::has_field(FieldID fid) const
    //--------------------------------------------------------------------------
    {
      return (logical_field == fid); 
    }

    //--------------------------------------------------------------------------
    void ReductionManager::has_fields(std::map<FieldID,bool> &fields) const
    //--------------------------------------------------------------------------
    {
      for (std::map<FieldID,bool>::iterator it = fields.begin();
            it != fields.end(); it++)
      {
        if (it->first == logical_field)
          it->second = true;
        else
          it->second = false;
      }
    }

    //--------------------------------------------------------------------------
    void ReductionManager::remove_space_fields(std::set<FieldID> &fields) const
    //--------------------------------------------------------------------------
    {
      fields.erase(logical_field);
    }

    //--------------------------------------------------------------------------
    DistributedID ReductionManager::send_manager(AddressSpaceID target)
    //--------------------------------------------------------------------------
    {
      if (!has_remote_instance(target))
      {
        // NO need to take the lock, duplicate sends are alright
        Serializer rez;
        {
          RezCheck z(rez);
          rez.serialize(did);
          rez.serialize(owner_space);
          rez.serialize(memory_manager->memory);
          rez.serialize(instance);
          rez.serialize(redop);
          rez.serialize(logical_field);
          rez.serialize(region_node->handle);
          rez.serialize<bool>(is_foldable());
          rez.serialize(get_pointer_space());
          rez.serialize(get_use_event());
        }
        // Now send the message
        context->runtime->send_reduction_manager(target, rez);
        update_remote_instances(target);
      }
      return did;
    }

    //--------------------------------------------------------------------------
    /*static*/ void ReductionManager::handle_send_manager(Runtime *runtime, 
                                     AddressSpaceID source, Deserializer &derez)
    //--------------------------------------------------------------------------
    {
      DerezCheck z(derez);
      DistributedID did;
      derez.deserialize(did);
      AddressSpaceID owner_space;
      derez.deserialize(owner_space);
      Memory mem;
      derez.deserialize(mem);
      PhysicalInstance inst;
      derez.deserialize(inst);
      ReductionOpID redop;
      derez.deserialize(redop);
      FieldID logical_field;
      derez.deserialize(logical_field);
      LogicalRegion handle;
      derez.deserialize(handle);
      bool foldable;
      derez.deserialize(foldable);
      Domain ptr_space;
      derez.deserialize(ptr_space);
      Event use_event;
      derez.deserialize(use_event);

      RegionNode *target_node = runtime->forest->get_node(handle);
      MemoryManager *memory = runtime->find_memory_manager(mem);
      const ReductionOp *op = Runtime::get_reduction_op(redop);
      if (foldable)
      {
        FoldReductionManager *manager = 
                        legion_new<FoldReductionManager>(
                                            runtime->forest, did, logical_field,
                                            owner_space, runtime->address_space,
                                            memory, inst, target_node, redop,op,
                                            use_event, false/*register now*/);
        if (!target_node->register_physical_manager(manager))
          legion_delete(manager);
        else
        {
          manager->register_with_runtime();
          manager->update_remote_instances(source);
        }
      }
      else
      {
        ListReductionManager *manager = 
                        legion_new<ListReductionManager>(
                                            runtime->forest, did, logical_field,
                                            owner_space, runtime->address_space,
                                            memory, inst, target_node, redop,op,
                                            ptr_space, false/*register now*/);
        if (!target_node->register_physical_manager(manager))
          legion_delete(manager);
        else
        {
          manager->register_with_runtime();
          manager->update_remote_instances(source);
        }
      }
    }

    //--------------------------------------------------------------------------
    ReductionView* ReductionManager::create_view(UniqueID context_uid)
    //--------------------------------------------------------------------------
    {
      DistributedID view_did = 
        context->runtime->get_available_distributed_id(false);
      ReductionView *result = legion_new<ReductionView>(context, view_did,
                                                context->runtime->address_space,
                                                context->runtime->address_space,
                                                region_node, this, 
                                                true/*reg*/, context_uid);
      return result;
    }

    /////////////////////////////////////////////////////////////
    // ListReductionManager 
    /////////////////////////////////////////////////////////////

    //--------------------------------------------------------------------------
    ListReductionManager::ListReductionManager(RegionTreeForest *ctx, 
                                               DistributedID did,
                                               FieldID f,
                                               AddressSpaceID owner_space, 
                                               AddressSpaceID local_space,
                                               MemoryManager *mem,
                                               PhysicalInstance inst, 
                                               RegionNode *node,
                                               ReductionOpID red,
                                               const ReductionOp *o, 
                                               Domain dom, bool reg_now)
      : ReductionManager(ctx, did, f, owner_space, local_space, mem, 
                         inst, node, red, o, reg_now), ptr_space(dom)
    //--------------------------------------------------------------------------
    {
#ifdef LEGION_GC
      log_garbage.info("GC List Reduction Manager %ld " IDFMT " " IDFMT " ",
                        did, inst.id, mem.id);
#endif
    }

    //--------------------------------------------------------------------------
    ListReductionManager::ListReductionManager(const ListReductionManager &rhs)
      : ReductionManager(NULL, 0, 0, 0, 0, NULL,
                         PhysicalInstance::NO_INST, NULL, 0, NULL, false),
        ptr_space(Domain::NO_DOMAIN)
    //--------------------------------------------------------------------------
    {
      // should never be called
      assert(false);
    }

    //--------------------------------------------------------------------------
    ListReductionManager::~ListReductionManager(void)
    //--------------------------------------------------------------------------
    {
      // Free up our pointer space
      ptr_space.get_index_space().destroy();
    }

    //--------------------------------------------------------------------------
    ListReductionManager& ListReductionManager::operator=(
                                                const ListReductionManager &rhs)
    //--------------------------------------------------------------------------
    {
      // should never be called
      assert(false);
      return *this;
    }

    //--------------------------------------------------------------------------
    LegionRuntime::Accessor::RegionAccessor<
      LegionRuntime::Accessor::AccessorType::Generic>
        ListReductionManager::get_accessor(void) const
    //--------------------------------------------------------------------------
    {
      // TODO: Implement this 
      assert(false);
      return instance.get_accessor();
    }

    //--------------------------------------------------------------------------
    LegionRuntime::Accessor::RegionAccessor<
      LegionRuntime::Accessor::AccessorType::Generic>
        ListReductionManager::get_field_accessor(FieldID fid) const
    //--------------------------------------------------------------------------
    {
      // should never be called
      assert(false);
      return instance.get_accessor();
    }

    //--------------------------------------------------------------------------
    size_t ListReductionManager::get_instance_size(void) const
    //--------------------------------------------------------------------------
    {
      size_t result = op->sizeof_rhs;
      if (ptr_space.get_dim() == 0)
      {
        const Realm::ElementMask &mask = 
          ptr_space.get_index_space().get_valid_mask();
        result *= mask.get_num_elmts();
      }
      else
        result *= ptr_space.get_volume();
      return result;
    }
    
    //--------------------------------------------------------------------------
    bool ListReductionManager::is_foldable(void) const
    //--------------------------------------------------------------------------
    {
      return false;
    }

    //--------------------------------------------------------------------------
    void ListReductionManager::find_field_offsets(const FieldMask &reduce_mask,
                                  std::vector<Domain::CopySrcDstField> &fields)
    //--------------------------------------------------------------------------
    {
#ifdef DEBUG_HIGH_LEVEL
      assert(instance.exists());
#endif
      // Assume that it's all the fields for right now
      // but offset by the pointer size
      fields.push_back(
          Domain::CopySrcDstField(instance, sizeof(ptr_t), op->sizeof_rhs));
    }

    //--------------------------------------------------------------------------
    Event ListReductionManager::issue_reduction(Operation *op,
        const std::vector<Domain::CopySrcDstField> &src_fields,
        const std::vector<Domain::CopySrcDstField> &dst_fields,
        Domain space, Event precondition, bool reduction_fold, bool precise)
    //--------------------------------------------------------------------------
    {
#ifdef DEBUG_HIGH_LEVEL
      assert(instance.exists());
#endif
      if (precise)
      {
        Domain::CopySrcDstField idx_field(instance, 0/*offset*/, sizeof(ptr_t));
        return context->issue_indirect_copy(space, op, idx_field, redop, 
                                            reduction_fold, src_fields, 
                                            dst_fields, precondition);
      }
      else
      {
        // TODO: teach the low-level runtime how to issue
        // partial reduction copies from a given space
        assert(false);
        return Event::NO_EVENT;
      }
    }

    //--------------------------------------------------------------------------
    Domain ListReductionManager::get_pointer_space(void) const
    //--------------------------------------------------------------------------
    {
      return ptr_space;
    }

    //--------------------------------------------------------------------------
    bool ListReductionManager::is_list_manager(void) const
    //--------------------------------------------------------------------------
    {
      return true;
    }

    //--------------------------------------------------------------------------
    ListReductionManager* ListReductionManager::as_list_manager(void) const
    //--------------------------------------------------------------------------
    {
      return const_cast<ListReductionManager*>(this);
    }

    //--------------------------------------------------------------------------
    FoldReductionManager* ListReductionManager::as_fold_manager(void) const
    //--------------------------------------------------------------------------
    {
      return NULL;
    }

    //--------------------------------------------------------------------------
    Event ListReductionManager::get_use_event(void) const
    //--------------------------------------------------------------------------
    {
      return Event::NO_EVENT;
    }

    /////////////////////////////////////////////////////////////
    // FoldReductionManager 
    /////////////////////////////////////////////////////////////

    //--------------------------------------------------------------------------
    FoldReductionManager::FoldReductionManager(RegionTreeForest *ctx, 
                                               DistributedID did,
                                               FieldID f,
                                               AddressSpaceID owner_space, 
                                               AddressSpaceID local_space,
                                               MemoryManager *mem,
                                               PhysicalInstance inst, 
                                               RegionNode *node,
                                               ReductionOpID red,
                                               const ReductionOp *o,
                                               Event u_event,
                                               bool register_now)
      : ReductionManager(ctx, did, f, owner_space, local_space, mem, 
                         inst, node, red, o, register_now), use_event(u_event)
    //--------------------------------------------------------------------------
    {
#ifdef LEGION_GC
      log_garbage.info("GC Fold Reduction Manager %ld " IDFMT " " IDFMT " ",
                        did, inst.id, mem.id);
#endif
    }

    //--------------------------------------------------------------------------
    FoldReductionManager::FoldReductionManager(const FoldReductionManager &rhs)
      : ReductionManager(NULL, 0, 0, 0, 0, NULL,
                         PhysicalInstance::NO_INST, NULL, 0, NULL, false),
        use_event(Event::NO_EVENT)
    //--------------------------------------------------------------------------
    {
      // should never be called
      assert(false);
    }

    //--------------------------------------------------------------------------
    FoldReductionManager::~FoldReductionManager(void)
    //--------------------------------------------------------------------------
    {
    }

    //--------------------------------------------------------------------------
    FoldReductionManager& FoldReductionManager::operator=(
                                                const FoldReductionManager &rhs)
    //--------------------------------------------------------------------------
    {
      // should never be called
      assert(false);
      return *this;
    }

    //--------------------------------------------------------------------------
    LegionRuntime::Accessor::RegionAccessor<
      LegionRuntime::Accessor::AccessorType::Generic>
        FoldReductionManager::get_accessor(void) const
    //--------------------------------------------------------------------------
    {
      return instance.get_accessor();
    }

    //--------------------------------------------------------------------------
    LegionRuntime::Accessor::RegionAccessor<
      LegionRuntime::Accessor::AccessorType::Generic>
        FoldReductionManager::get_field_accessor(FieldID fid) const
    //--------------------------------------------------------------------------
    {
      // should never be called
      assert(false);
      return instance.get_accessor();
    }

    //--------------------------------------------------------------------------
    size_t FoldReductionManager::get_instance_size(void) const
    //--------------------------------------------------------------------------
    {
      size_t result = op->sizeof_rhs;
      const Domain &d = region_node->row_source->get_domain_blocking();
      if (d.get_dim() == 0)
      {
        const Realm::ElementMask &mask = 
          d.get_index_space().get_valid_mask();
        result *= mask.get_num_elmts();
      }
      else
        result *= d.get_volume();
      return result;
    }
    
    //--------------------------------------------------------------------------
    bool FoldReductionManager::is_foldable(void) const
    //--------------------------------------------------------------------------
    {
      return true;
    }

    //--------------------------------------------------------------------------
    void FoldReductionManager::find_field_offsets(const FieldMask &reduce_mask,
                                  std::vector<Domain::CopySrcDstField> &fields)
    //--------------------------------------------------------------------------
    {
#ifdef DEBUG_HIGH_LEVEL
      assert(instance.exists());
#endif
      // Assume that its all the fields for now
      // until we find a different way to do reductions on a subset of fields
      fields.push_back(
          Domain::CopySrcDstField(instance, 0/*offset*/, op->sizeof_rhs));
    }

    //--------------------------------------------------------------------------
    Event FoldReductionManager::issue_reduction(Operation *op,
        const std::vector<Domain::CopySrcDstField> &src_fields,
        const std::vector<Domain::CopySrcDstField> &dst_fields,
        Domain space, Event precondition, bool reduction_fold, bool precise)
    //--------------------------------------------------------------------------
    {
#ifdef DEBUG_HIGH_LEVEL
      assert(instance.exists());
#endif
      // Doesn't matter if this one is precise or not
      return context->issue_reduction_copy(space, op, redop, reduction_fold,
                                         src_fields, dst_fields, precondition);
    }

    //--------------------------------------------------------------------------
    Domain FoldReductionManager::get_pointer_space(void) const
    //--------------------------------------------------------------------------
    {
      return Domain::NO_DOMAIN;
    }

    //--------------------------------------------------------------------------
    bool FoldReductionManager::is_list_manager(void) const
    //--------------------------------------------------------------------------
    {
      return false;
    }

    //--------------------------------------------------------------------------
    ListReductionManager* FoldReductionManager::as_list_manager(void) const
    //--------------------------------------------------------------------------
    {
      return NULL;
    }

    //--------------------------------------------------------------------------
    FoldReductionManager* FoldReductionManager::as_fold_manager(void) const
    //--------------------------------------------------------------------------
    {
      return const_cast<FoldReductionManager*>(this);
    }

    //--------------------------------------------------------------------------
    Event FoldReductionManager::get_use_event(void) const
    //--------------------------------------------------------------------------
    {
      return use_event;
    }

    /////////////////////////////////////////////////////////////
    // Instance Builder
    /////////////////////////////////////////////////////////////

    //--------------------------------------------------------------------------
    size_t InstanceBuilder::compute_needed_size(RegionTreeForest *forest)
    //--------------------------------------------------------------------------
    {
      if (!valid)
        initialize(forest);
      return 0;
    }

    //--------------------------------------------------------------------------
    PhysicalManager* InstanceBuilder::create_physical_instance(
                                                       RegionTreeForest *forest)
    //--------------------------------------------------------------------------
    {
      if (!valid)
        initialize(forest);
      return NULL;
    }

    //--------------------------------------------------------------------------
    void InstanceBuilder::initialize(RegionTreeForest *forest)
    //--------------------------------------------------------------------------
    {
      compute_ancestor_and_domain(forest); 
#ifdef NEW_INSTANCE_CREATION

#else
      compute_old_parameters();
#endif
    }

    //--------------------------------------------------------------------------
    void InstanceBuilder::compute_ancestor_and_domain(RegionTreeForest *forest)
    //--------------------------------------------------------------------------
    {
      // First let's get the domain for this region 
      ancestor = forest->get_node(regions[0]);
      if (regions.size() > 1)
      {
        // Compute an union of the all the index spaces for the basis
        // and the common ancestor of all regions
        const Domain &first = ancestor->row_source->get_domain_blocking();
        switch (first.get_dim())
        {
          case 0:
            {
              Realm::ElementMask result = 
                first.get_index_space().get_valid_mask();
              for (unsigned idx = 1; idx < regions.size(); idx++)
              {
                RegionNode *next = forest->get_node(regions[idx]);
                const Domain &next_domain = next->get_domain_blocking();
                result |= next_domain.get_index_space().get_valid_mask();
                // Find the common ancestor
                ancestor = find_common_ancestor(ancestor, next);
              }
              instance_domain = Domain(
                  Realm::IndexSpace::create_index_space(result));
              own_domain = true;
              break;
            }
          case 1:
            {
              LegionRuntime::Arrays::Rect<1> result = first.get_rect<1>();
              for (unsigned idx = 1; idx < regions.size(); idx++)
              {
                RegionNode *next = forest->get_node(regions[idx]);
                const Domain &next_domain = next->get_domain_blocking();
                LegionRuntime::Arrays::Rect<1> next_rect = 
                  next_domain.get_rect<1>();
                result = result.convex_hull(next_rect);
                // Find the common ancesstor
                ancestor = find_common_ancestor(ancestor, next); 
              }
              instance_domain = Domain::from_rect<1>(result);
              break;
            }
          case 2:
            {
              LegionRuntime::Arrays::Rect<2> result = first.get_rect<2>();
              for (unsigned idx = 1; idx < regions.size(); idx++)
              {
                RegionNode *next = forest->get_node(regions[idx]);
                const Domain &next_domain = next->get_domain_blocking();
                LegionRuntime::Arrays::Rect<2> next_rect = 
                  next_domain.get_rect<2>();
                result = result.convex_hull(next_rect);
                // Find the common ancesstor
                ancestor = find_common_ancestor(ancestor, next); 
              }
              instance_domain = Domain::from_rect<2>(result);
              break;
            }
          case 3:
            {
              LegionRuntime::Arrays::Rect<3> result = first.get_rect<3>();
              for (unsigned idx = 1; idx < regions.size(); idx++)
              {
                RegionNode *next = forest->get_node(regions[idx]);
                const Domain &next_domain = next->get_domain_blocking();
                LegionRuntime::Arrays::Rect<3> next_rect = 
                  next_domain.get_rect<3>();
                result = result.convex_hull(next_rect);
                // Find the common ancesstor
                ancestor = find_common_ancestor(ancestor, next); 
              }
              instance_domain = Domain::from_rect<3>(result);
              break;
            }
          default:
            assert(false); // unsupported number of dimensions
        }
      }
      else
        instance_domain = ancestor->row_source->get_domain_blocking();
    }

    //--------------------------------------------------------------------------
    RegionNode* InstanceBuilder::find_common_ancestor(RegionNode *one,
                                                      RegionNode *two) const
    //--------------------------------------------------------------------------
    {
      // Make them the same level
      while (one->row_source->depth > two->row_source->depth)
      {
#ifdef DEBUG_HIGH_LEVEL
        assert(one->parent != NULL);
#endif
        one = one->parent->parent;
      }
      while (one->row_source->depth < two->row_source->depth)
      {
#ifdef DEBUG_HIGH_LEVEL
        assert(two->parent != NULL);
#endif
        two = two->parent->parent;
      }
      // While they are not the same, make them both go up
      while (one != two)
      {
#ifdef DEBUG_HIGH_LEVEL
        assert(one->parent != NULL);
        assert(two->parent != NULL);
#endif
        one = one->parent->parent;
        two = two->parent->parent;
      }
      return one;
    }

    //--------------------------------------------------------------------------
    void InstanceBuilder::compute_new_parameters(void)
    //--------------------------------------------------------------------------
    {

    }

    //--------------------------------------------------------------------------
    void InstanceBuilder::compute_old_parameters(void)
    //--------------------------------------------------------------------------
    {
      
    }

  }; // namespace Internal 
}; // namespace Legion

