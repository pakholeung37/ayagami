use ayagami::core::{AlphaBlendMode, ArtMesh, ColorBlendMode, Item, Model, Param, Part};
use ayagami::driver::{DrawNode, Driver};
use ayagami::file::ParsedModel;
use std::ffi::{CString, c_char, c_void};
use std::io::Cursor;
use std::ptr;
use std::slice;
use std::sync::{Arc, Mutex};

#[repr(C)]
#[derive(Clone, Copy, Default)]
pub struct CsmVector2 {
    x: f32,
    y: f32,
}

#[repr(C)]
#[derive(Clone, Copy, Default)]
pub struct CsmVector4 {
    x: f32,
    y: f32,
    z: f32,
    w: f32,
}

type LogFunction = Option<unsafe extern "C" fn(*const c_char)>;
static LOG_FUNCTION: Mutex<LogFunction> = Mutex::new(None);

struct MocState {
    model: Arc<ParsedModel>,
}

#[allow(dead_code)] // Owner fields intentionally keep all exported raw pointers alive.
struct CoreModel {
    model: Arc<ParsedModel>,
    driver: Driver<ParsedModel>,

    parameter_ids: Vec<CString>,
    parameter_id_ptrs: Vec<*const c_char>,
    parameter_types: Vec<i32>,
    parameter_minimums: Vec<f32>,
    parameter_maximums: Vec<f32>,
    parameter_defaults: Vec<f32>,
    parameter_values: Vec<f32>,
    parameter_repeats: Vec<i32>,
    parameter_key_counts: Vec<i32>,
    parameter_key_values: Vec<Vec<f32>>,
    parameter_key_ptrs: Vec<*const f32>,

    part_ids: Vec<CString>,
    part_id_ptrs: Vec<*const c_char>,
    part_opacities: Vec<f32>,
    part_parents: Vec<i32>,
    part_offscreens: Vec<i32>,

    drawable_ids: Vec<CString>,
    drawable_id_ptrs: Vec<*const c_char>,
    drawable_constant_flags: Vec<u8>,
    drawable_dynamic_flags: Vec<u8>,
    drawable_blend_modes: Vec<i32>,
    drawable_texture_indices: Vec<i32>,
    drawable_draw_orders: Vec<i32>,
    render_orders: Vec<i32>,
    drawable_opacities: Vec<f32>,
    drawable_mask_counts: Vec<i32>,
    drawable_masks: Vec<Vec<i32>>,
    drawable_mask_ptrs: Vec<*const i32>,
    drawable_vertex_counts: Vec<i32>,
    drawable_vertices: Vec<Vec<CsmVector2>>,
    drawable_vertex_ptrs: Vec<*const CsmVector2>,
    drawable_uvs: Vec<Vec<CsmVector2>>,
    drawable_uv_ptrs: Vec<*const CsmVector2>,
    drawable_index_counts: Vec<i32>,
    drawable_indices: Vec<Vec<u16>>,
    drawable_index_ptrs: Vec<*const u16>,
    drawable_multiply_colors: Vec<CsmVector4>,
    drawable_screen_colors: Vec<CsmVector4>,
    drawable_parent_parts: Vec<i32>,
}

fn cstring(value: &str) -> CString {
    CString::new(value).unwrap_or_else(|_| CString::new("invalid-id").unwrap())
}

fn vec2(v: ayagami::core::Coord) -> CsmVector2 {
    // Ayagami uses screen-style Y-down model coordinates; Cubism Core exposes
    // Y-up coordinates and gd_cubism flips them for Godot.
    CsmVector2 { x: v.x, y: -v.y }
}

fn core_uv(v: ayagami::core::Coord) -> CsmVector2 {
    // Ayagami exposes top-left-origin texture coordinates. Cubism Core's ABI
    // exposes bottom-left-origin V, which gd_cubism converts back for Godot.
    CsmVector2 {
        x: v.x,
        y: 1.0 - v.y,
    }
}

fn vec4(v: [f32; 3], alpha: f32) -> CsmVector4 {
    CsmVector4 {
        x: v[0],
        y: v[1],
        z: v[2],
        w: alpha,
    }
}

fn blend_mode(color: ColorBlendMode, alpha: AlphaBlendMode) -> i32 {
    color as i32 | ((alpha as i32) << 8)
}

impl CoreModel {
    fn collect_render_order(&self, part: Option<u32>, order: &mut Vec<u32>) {
        for node in self.driver.draw_nodes(part).unwrap_or_default() {
            match node {
                DrawNode::ArtMesh(uid) => order.push(*uid),
                DrawNode::OffscreenPart(uid) => self.collect_render_order(Some(*uid), order),
            }
        }
    }

    fn new(model: Arc<ParsedModel>) -> Self {
        let mut driver = Driver::new(model.as_ref());
        driver.drive(model.as_ref());

        let params: Vec<_> = model.params().into_iter().collect();
        let parameter_ids: Vec<_> = params.iter().map(|p| cstring(p.id())).collect();
        let parameter_id_ptrs = parameter_ids.iter().map(|s| s.as_ptr()).collect();
        let parameter_key_values: Vec<Vec<f32>> = params
            .iter()
            .map(|p| p.keypoints().unwrap_or(&[]).to_vec())
            .collect();
        let parameter_key_ptrs = parameter_key_values
            .iter()
            .map(|v| {
                if v.is_empty() {
                    ptr::null()
                } else {
                    v.as_ptr()
                }
            })
            .collect();

        let parts: Vec<_> = model.parts().into_iter().collect();
        let part_ids: Vec<_> = parts.iter().map(|p| cstring(p.id())).collect();
        let part_id_ptrs = part_ids.iter().map(|s| s.as_ptr()).collect();

        let artmeshes: Vec<_> = model.artmeshes().into_iter().collect();
        let drawable_ids: Vec<_> = artmeshes.iter().map(|a| cstring(a.id())).collect();
        let drawable_id_ptrs = drawable_ids.iter().map(|s| s.as_ptr()).collect();
        let index_buffer = model.index_buffer().unwrap_or(&[]);
        let uv_buffer = model.texcoord_buffer().unwrap_or(&[]);

        let mut drawable_masks: Vec<Vec<i32>> = Vec::with_capacity(artmeshes.len());
        let mut drawable_uvs: Vec<Vec<CsmVector2>> = Vec::with_capacity(artmeshes.len());
        let mut drawable_indices: Vec<Vec<u16>> = Vec::with_capacity(artmeshes.len());
        for a in &artmeshes {
            drawable_masks.push(a.clips().into_iter().map(|m| m.uid() as i32).collect());
            let uv_start = a.texcoord_offset() as usize;
            let uv_end = uv_start + a.vertex_count() as usize;
            drawable_uvs.push(
                uv_buffer[uv_start..uv_end]
                    .iter()
                    .copied()
                    .map(core_uv)
                    .collect(),
            );
            let range = a.index_range();
            drawable_indices.push(index_buffer[range.start as usize..range.end as usize].to_vec());
        }

        let drawable_mask_ptrs = drawable_masks.iter().map(|v| v.as_ptr()).collect();
        let drawable_uv_ptrs = drawable_uvs.iter().map(|v| v.as_ptr()).collect();
        let drawable_index_ptrs = drawable_indices.iter().map(|v| v.as_ptr()).collect();
        let drawable_vertices: Vec<Vec<CsmVector2>> = artmeshes
            .iter()
            .map(|a| {
                driver
                    .artmesh_state(a.uid())
                    .map(|s| s.vertices.iter().copied().map(vec2).collect())
                    .unwrap_or_default()
            })
            .collect();
        let drawable_vertex_ptrs = drawable_vertices.iter().map(|v| v.as_ptr()).collect();

        let mut result = Self {
            model: model.clone(),
            driver,
            parameter_ids,
            parameter_id_ptrs,
            parameter_types: params
                .iter()
                .map(|p| i32::from(p.is_blendshape()))
                .collect(),
            parameter_minimums: params.iter().map(|p| p.min()).collect(),
            parameter_maximums: params.iter().map(|p| p.max()).collect(),
            parameter_defaults: params.iter().map(|p| p.default()).collect(),
            parameter_values: params.iter().map(|p| p.default()).collect(),
            parameter_repeats: params.iter().map(|p| i32::from(p.repeat())).collect(),
            parameter_key_counts: parameter_key_values
                .iter()
                .map(|v| v.len() as i32)
                .collect(),
            parameter_key_values,
            parameter_key_ptrs,
            part_ids,
            part_id_ptrs,
            part_opacities: vec![1.0; parts.len()],
            part_parents: parts
                .iter()
                .map(|p| p.parent().map(|v| v.uid() as i32).unwrap_or(-1))
                .collect(),
            part_offscreens: vec![-1; parts.len()],
            drawable_ids,
            drawable_id_ptrs,
            drawable_constant_flags: artmeshes
                .iter()
                .map(|a| {
                    let mut flags = if a.culling() { 0 } else { 1 << 2 };
                    if a.invert_mask() {
                        flags |= 1 << 3;
                    }
                    match a.blend_config().simple() {
                        Some(ayagami::core::BlendMode::Add) => flags |= 1,
                        Some(ayagami::core::BlendMode::Multiply) => flags |= 1 << 1,
                        _ => {}
                    }
                    flags
                })
                .collect(),
            drawable_dynamic_flags: vec![0; artmeshes.len()],
            drawable_blend_modes: artmeshes
                .iter()
                .map(|a| blend_mode(a.blend_config().color, a.blend_config().alpha))
                .collect(),
            drawable_texture_indices: artmeshes.iter().map(|a| a.texture() as i32).collect(),
            drawable_draw_orders: vec![0; artmeshes.len()],
            render_orders: vec![0; artmeshes.len()],
            drawable_opacities: vec![0.0; artmeshes.len()],
            drawable_mask_counts: drawable_masks.iter().map(|v| v.len() as i32).collect(),
            drawable_masks,
            drawable_mask_ptrs,
            drawable_vertex_counts: artmeshes.iter().map(|a| a.vertex_count() as i32).collect(),
            drawable_vertices,
            drawable_vertex_ptrs,
            drawable_uvs,
            drawable_uv_ptrs,
            drawable_index_counts: drawable_indices.iter().map(|v| v.len() as i32).collect(),
            drawable_indices,
            drawable_index_ptrs,
            drawable_multiply_colors: vec![CsmVector4::default(); artmeshes.len()],
            drawable_screen_colors: vec![CsmVector4::default(); artmeshes.len()],
            drawable_parent_parts: artmeshes
                .iter()
                .map(|a| a.part().map(|v| v.uid() as i32).unwrap_or(-1))
                .collect(),
        };
        result.update();
        result
    }

    fn update(&mut self) {
        for (i, value) in self.parameter_values.iter().copied().enumerate() {
            let _ = self.driver.set_param(i as u32, value);
        }
        for (i, opacity) in self.part_opacities.iter().copied().enumerate() {
            let _ = self.driver.set_part_opacity(i as u32, opacity);
        }
        self.driver.drive(self.model.as_ref());

        // Core's render-order array is the final, dense rank of each drawable,
        // not Ayagami's interpolated depth value. gd_cubism uses it directly as
        // a CanvasItem z-index, so feeding depths here breaks occlusion badly.
        let mut order = Vec::with_capacity(self.drawable_vertices.len());
        self.collect_render_order(None, &mut order);
        for (rank, uid) in order.into_iter().enumerate() {
            self.render_orders[uid as usize] = rank as i32;
        }

        for i in 0..self.drawable_vertices.len() {
            let Some(state) = self.driver.artmesh_state(i as u32) else {
                continue;
            };
            let vertices = &mut self.drawable_vertices[i];
            vertices.clear();
            vertices.extend(state.vertices.iter().copied().map(vec2));
            self.drawable_vertex_ptrs[i] = vertices.as_ptr();
            self.drawable_opacities[i] = state.visual.opacity;
            self.drawable_multiply_colors[i] = vec4(state.visual.multiply_color.to_array(), 1.0);
            self.drawable_screen_colors[i] = vec4(state.visual.screen_color.to_array(), 1.0);
            self.drawable_draw_orders[i] = state.depth;
            self.drawable_dynamic_flags[i] = u8::from(state.visual.visible)
                | (1 << 1)
                | (1 << 2)
                | (1 << 3)
                | (1 << 4)
                | (1 << 5)
                | (1 << 6);
        }
    }
}

unsafe fn moc_state<'a>(moc: *const c_void) -> Option<&'a MocState> {
    if moc.is_null() {
        return None;
    }
    let slot = unsafe { (moc as *const u8).add(8) as *const *mut MocState };
    unsafe { slot.read().as_ref() }
}

unsafe fn core<'a>(model: *const c_void) -> Option<&'a CoreModel> {
    if model.is_null() {
        return None;
    }
    unsafe { (*(model as *const *mut CoreModel)).as_ref() }
}

unsafe fn core_mut<'a>(model: *mut c_void) -> Option<&'a mut CoreModel> {
    if model.is_null() {
        return None;
    }
    unsafe { (*(model as *mut *mut CoreModel)).as_mut() }
}

fn moc_version(address: *const c_void, size: u32) -> u32 {
    if address.is_null() || size < 8 {
        return 0;
    }
    let bytes = unsafe { slice::from_raw_parts(address as *const u8, 8) };
    if &bytes[..4] != b"MOC3" {
        return 0;
    }
    u32::from_le_bytes(bytes[4..8].try_into().unwrap())
}

#[unsafe(no_mangle)]
pub extern "C" fn csmGetVersion() -> u32 {
    0x05030000
}
#[unsafe(no_mangle)]
pub extern "C" fn csmGetLatestMocVersion() -> u32 {
    6
}
#[unsafe(no_mangle)]
pub extern "C" fn csmGetMocVersion(a: *const c_void, s: u32) -> u32 {
    moc_version(a, s)
}

#[unsafe(no_mangle)]
pub extern "C" fn csmHasMocConsistency(address: *mut c_void, size: u32) -> i32 {
    if address.is_null() {
        return 0;
    }
    let bytes = unsafe { slice::from_raw_parts(address as *const u8, size as usize) };
    i32::from(ParsedModel::load(&mut Cursor::new(bytes)).is_ok())
}

#[unsafe(no_mangle)]
pub extern "C" fn csmGetLogFunction() -> LogFunction {
    *LOG_FUNCTION.lock().unwrap()
}
#[unsafe(no_mangle)]
pub extern "C" fn csmSetLogFunction(f: LogFunction) {
    *LOG_FUNCTION.lock().unwrap() = f;
}

#[unsafe(no_mangle)]
pub extern "C" fn csmReviveMocInPlace(address: *mut c_void, size: u32) -> *mut c_void {
    if address.is_null() || size < 16 {
        return ptr::null_mut();
    }
    let bytes = unsafe { slice::from_raw_parts(address as *const u8, size as usize) };
    let Ok(model) = ParsedModel::load(&mut Cursor::new(bytes)) else {
        return ptr::null_mut();
    };
    let state = Box::into_raw(Box::new(MocState {
        model: Arc::new(model),
    }));
    unsafe {
        ((address as *mut u8).add(8) as *mut *mut MocState).write(state);
    }
    address
}

#[unsafe(no_mangle)]
pub extern "C" fn csmGetSizeofModel(moc: *const c_void) -> u32 {
    if unsafe { moc_state(moc) }.is_some() {
        16
    } else {
        0
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn csmInitializeModelInPlace(
    moc: *const c_void,
    address: *mut c_void,
    size: u32,
) -> *mut c_void {
    if address.is_null() || size < 16 {
        return ptr::null_mut();
    }
    let Some(moc) = (unsafe { moc_state(moc) }) else {
        return ptr::null_mut();
    };
    let state = Box::into_raw(Box::new(CoreModel::new(moc.model.clone())));
    unsafe {
        (address as *mut *mut CoreModel).write(state);
    }
    address
}

#[unsafe(no_mangle)]
pub extern "C" fn csmUpdateModel(m: *mut c_void) {
    if let Some(m) = unsafe { core_mut(m) } {
        m.update();
    }
}
#[unsafe(no_mangle)]
pub extern "C" fn csmGetRenderOrders(m: *const c_void) -> *const i32 {
    unsafe { core(m).map_or(ptr::null(), |m| m.render_orders.as_ptr()) }
}

#[unsafe(no_mangle)]
pub extern "C" fn csmReadCanvasInfo(
    m: *const c_void,
    size: *mut CsmVector2,
    origin: *mut CsmVector2,
    ppu: *mut f32,
) {
    let Some(m) = (unsafe { core(m) }) else {
        return;
    };
    let c = m.model.canvas_properties();
    unsafe {
        // Ayagami stores canvas dimensions/origin in pixels and vertices in
        // model units. Cubism Core exposes the same split plus pixels-per-unit.
        if let Some(v) = size.as_mut() {
            *v = CsmVector2 {
                x: c.dimensions.x,
                y: c.dimensions.y,
            };
        }
        if let Some(v) = origin.as_mut() {
            *v = CsmVector2 {
                x: c.center.x,
                y: c.center.y,
            };
        }
        if let Some(v) = ppu.as_mut() {
            *v = c.scale;
        }
    }
}

macro_rules! count_fn {
    ($name:ident, $field:ident) => {
        #[unsafe(no_mangle)]
        pub extern "C" fn $name(m: *const c_void) -> i32 {
            unsafe { core(m).map_or(-1, |m| m.$field.len() as i32) }
        }
    };
}
macro_rules! ptr_fn {
    ($name:ident, $field:ident, $ty:ty) => {
        #[unsafe(no_mangle)]
        pub extern "C" fn $name(m: *const c_void) -> *const $ty {
            unsafe { core(m).map_or(ptr::null(), |m| m.$field.as_ptr()) }
        }
    };
}
macro_rules! mut_ptr_fn {
    ($name:ident, $field:ident, $ty:ty) => {
        #[unsafe(no_mangle)]
        pub extern "C" fn $name(m: *mut c_void) -> *mut $ty {
            unsafe { core_mut(m).map_or(ptr::null_mut(), |m| m.$field.as_mut_ptr()) }
        }
    };
}

count_fn!(csmGetParameterCount, parameter_values);
ptr_fn!(csmGetParameterIds, parameter_id_ptrs, *const c_char);
ptr_fn!(csmGetParameterTypes, parameter_types, i32);
ptr_fn!(csmGetParameterMinimumValues, parameter_minimums, f32);
ptr_fn!(csmGetParameterMaximumValues, parameter_maximums, f32);
ptr_fn!(csmGetParameterDefaultValues, parameter_defaults, f32);
mut_ptr_fn!(csmGetParameterValues, parameter_values, f32);
ptr_fn!(csmGetParameterRepeats, parameter_repeats, i32);
ptr_fn!(csmGetParameterKeyCounts, parameter_key_counts, i32);
ptr_fn!(csmGetParameterKeyValues, parameter_key_ptrs, *const f32);

count_fn!(csmGetPartCount, part_opacities);
ptr_fn!(csmGetPartIds, part_id_ptrs, *const c_char);
mut_ptr_fn!(csmGetPartOpacities, part_opacities, f32);
ptr_fn!(csmGetPartParentPartIndices, part_parents, i32);
ptr_fn!(csmGetPartOffscreenIndices, part_offscreens, i32);

count_fn!(csmGetDrawableCount, drawable_opacities);
ptr_fn!(csmGetDrawableIds, drawable_id_ptrs, *const c_char);
ptr_fn!(csmGetDrawableConstantFlags, drawable_constant_flags, u8);
ptr_fn!(csmGetDrawableDynamicFlags, drawable_dynamic_flags, u8);
ptr_fn!(csmGetDrawableBlendModes, drawable_blend_modes, i32);
ptr_fn!(csmGetDrawableTextureIndices, drawable_texture_indices, i32);
ptr_fn!(csmGetDrawableDrawOrders, drawable_draw_orders, i32);
ptr_fn!(csmGetDrawableOpacities, drawable_opacities, f32);
ptr_fn!(csmGetDrawableMaskCounts, drawable_mask_counts, i32);
ptr_fn!(csmGetDrawableMasks, drawable_mask_ptrs, *const i32);
ptr_fn!(csmGetDrawableVertexCounts, drawable_vertex_counts, i32);
ptr_fn!(
    csmGetDrawableVertexPositions,
    drawable_vertex_ptrs,
    *const CsmVector2
);
ptr_fn!(csmGetDrawableVertexUvs, drawable_uv_ptrs, *const CsmVector2);
ptr_fn!(csmGetDrawableIndexCounts, drawable_index_counts, i32);
ptr_fn!(csmGetDrawableIndices, drawable_index_ptrs, *const u16);
ptr_fn!(
    csmGetDrawableMultiplyColors,
    drawable_multiply_colors,
    CsmVector4
);
ptr_fn!(
    csmGetDrawableScreenColors,
    drawable_screen_colors,
    CsmVector4
);
ptr_fn!(csmGetDrawableParentPartIndices, drawable_parent_parts, i32);

#[unsafe(no_mangle)]
pub extern "C" fn csmResetDrawableDynamicFlags(_: *mut c_void) {
    // Cubism Framework calls this immediately after csmUpdateModel(), before
    // gd_cubism reads the exported flags. The native Core keeps that update's
    // flags observable to the renderer; clearing our public array here made
    // dynamic mask AABBs remain at their initial pose while vertices moved.
}

#[unsafe(no_mangle)]
pub extern "C" fn csmGetOffscreenCount(_: *const c_void) -> i32 {
    0
}
#[unsafe(no_mangle)]
pub extern "C" fn csmGetOffscreenBlendModes(_: *const c_void) -> *const i32 {
    ptr::null()
}
#[unsafe(no_mangle)]
pub extern "C" fn csmGetOffscreenOpacities(_: *const c_void) -> *const f32 {
    ptr::null()
}
#[unsafe(no_mangle)]
pub extern "C" fn csmGetOffscreenOwnerIndices(_: *const c_void) -> *const i32 {
    ptr::null()
}
#[unsafe(no_mangle)]
pub extern "C" fn csmGetOffscreenMultiplyColors(_: *const c_void) -> *const CsmVector4 {
    ptr::null()
}
#[unsafe(no_mangle)]
pub extern "C" fn csmGetOffscreenScreenColors(_: *const c_void) -> *const CsmVector4 {
    ptr::null()
}
#[unsafe(no_mangle)]
pub extern "C" fn csmGetOffscreenMaskCounts(_: *const c_void) -> *const i32 {
    ptr::null()
}
#[unsafe(no_mangle)]
pub extern "C" fn csmGetOffscreenMasks(_: *const c_void) -> *const *const i32 {
    ptr::null()
}
#[unsafe(no_mangle)]
pub extern "C" fn csmGetOffscreenConstantFlags(_: *const c_void) -> *const u8 {
    ptr::null()
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs::File;
    use std::path::PathBuf;

    #[test]
    fn rejects_non_moc_data() {
        let mut bytes = vec![0_u8; 64];
        assert_eq!(
            csmHasMocConsistency(bytes.as_mut_ptr().cast(), bytes.len() as u32),
            0
        );
        assert!(csmReviveMocInPlace(bytes.as_mut_ptr().cast(), bytes.len() as u32).is_null());
    }

    #[test]
    fn mao_model_exposes_the_expected_core_shape() {
        let path = PathBuf::from(env!("CARGO_MANIFEST_DIR"))
            .join("../../demos/godot/assets/live2d/mao/runtime/mao_pro.moc3");
        let model = Arc::new(ParsedModel::load(&mut File::open(path).unwrap()).unwrap());
        let core = CoreModel::new(model);
        assert_eq!(core.parameter_values.len(), 128);
        assert_eq!(core.drawable_vertices.len(), 260);
        assert!(core.drawable_mask_counts.iter().any(|count| *count > 0));
        assert!(core.drawable_opacities.iter().any(|opacity| *opacity > 0.0));
        let mut render_orders = core.render_orders.clone();
        render_orders.sort_unstable();
        assert_eq!(render_orders, (0..260).collect::<Vec<_>>());
        assert!(
            core.drawable_vertices
                .iter()
                .all(|vertices| !vertices.is_empty())
        );
    }
}
