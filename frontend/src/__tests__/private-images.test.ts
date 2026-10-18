import { privateImagePath,privateImageSrc } from '@/lib/private-image';
import { GET } from '@/app/api/private-image/route';
import { createSupabaseServerClient } from '@/lib/supabase/server';
jest.mock('@/lib/supabase/server',()=>({createSupabaseServerClient:jest.fn()}));
const path='d4000000-0000-0000-0000-000000000003/Photo one.jpg';
const source='https://storage.test/storage/v1/object/public/item-images/'+path;
const session=jest.fn(),upstream=jest.fn();
beforeEach(()=>{jest.clearAllMocks();process.env.NEXT_PUBLIC_API_BASE_URL='https://api.test';process.env.NEXT_PUBLIC_SUPABASE_URL='https://storage.test';global.fetch=upstream;jest.mocked(createSupabaseServerClient).mockResolvedValue({auth:{getSession:session}} as never);session.mockResolvedValue({data:{session:{access_token:'actor-token'}},error:null});});
test('legacy public and signed locators use an authenticated same-origin path',()=>{
 expect(privateImagePath(source)).toBe(path);
 expect(privateImageSrc(source.replace('/public/','/sign/')+'?token=old-secret')).toBe('/api/private-image?path='+encodeURIComponent(path));
 expect(privateImageSrc(source)).not.toContain('token');
 expect(privateImageSrc('https://vendor.test/image.jpg')).toBe('https://vendor.test/image.jpg');
 expect(privateImageSrc('blob:local')).toBe('blob:local');
 expect(privateImagePath(source.replace('Photo one.jpg','%252e%252e/file.jpg'))).toBeNull();
});
test('copying the proxy URL without a session grants no image access',async()=>{
 session.mockResolvedValue({data:{session:null},error:null});
 const result=await GET(new Request('https://findez.test/api/private-image?path='+encodeURIComponent(path)));
 expect(result.status).toBe(401);expect(upstream).not.toHaveBeenCalled();
});
test('authorized image loads use a header token and are never cached or redirected',async()=>{
 upstream.mockResolvedValue(new Response('photo',{headers:{'content-type':'image/jpeg'}}));
 const result=await GET(new Request('https://findez.test/api/private-image?path='+encodeURIComponent(path)));
 expect(result.status).toBe(200);expect(await result.text()).toBe('photo');
 expect(result.headers.get('cache-control')).toContain('no-store');
 expect(upstream.mock.calls[0][0]).toBe('https://api.test/media/item-image?path='+encodeURIComponent(path));
 expect(upstream.mock.calls[0][1]).toMatchObject({headers:{Authorization:'Bearer actor-token'},cache:'no-store',redirect:'error'});
 expect(upstream.mock.calls[0][0]).not.toContain('actor-token');
});
test('revoked access from the API cannot fall back to a public URL',async()=>{
 upstream.mockResolvedValue(new Response(null,{status:404}));
 const result=await GET(new Request('https://findez.test/api/private-image?path='+encodeURIComponent(path)));
 expect(result.status).toBe(404);expect(await result.text()).toBe('');expect(result.headers.get('location')).toBeNull();
});
test('a path cannot select an upstream server or escape the bucket',async()=>{
 for(const bad of ['https://evil.test/x','../photo.jpg',path+'/../other.jpg']){
  expect((await GET(new Request('https://findez.test/api/private-image?path='+encodeURIComponent(bad)))).status).toBe(400);
 }
 expect(upstream).not.toHaveBeenCalled();
});

test('account changes produce distinct browser image cache keys without granting access',()=>{
 expect(privateImageSrc(source,'actor-a')).not.toBe(privateImageSrc(source,'actor-b'));
 expect(privateImageSrc(source,'actor-a')).not.toContain('token');
});

test('third-party product images never use a FindEZ session',()=>{expect(privateImageSrc(source.replace('storage.test','vendor.test'))).toBe(source.replace('storage.test','vendor.test'));});
